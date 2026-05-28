#include "McpServer.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QString>

#include <cstdio>

namespace dias {

namespace {

constexpr const char* kProtocolVersion = "2024-11-05";
constexpr const char* kServerName      = "dias-mcp";
constexpr const char* kServerVersion   = "0.1.0";

QString isoLocal(const QDateTime& dt) {
    return dt.isValid() ? dt.toString(Qt::ISODate) : QString();
}

QDateTime parseIso(const QString& s) {
    // Accept ISO 8601 in local time, with or without seconds.
    return QDateTime::fromString(s, Qt::ISODate);
}

QJsonObject eventJson(const Event& e) {
    QJsonObject o;
    o["id"]             = e.id;
    o["title"]          = e.title;
    o["start"]          = isoLocal(e.start);
    o["end"]            = isoLocal(e.end);
    o["all_day"]        = e.allDay;
    o["category"]       = e.category;
    o["source"]         = e.source;
    o["created_by"]     = e.createdBy;
    o["last_edited_by"] = e.lastEditedBy;
    if (!e.rrule.isEmpty()) o["rrule"] = e.rrule;
    return o;
}

QJsonObject taskJson(const Task& t) {
    QJsonObject o;
    o["id"]             = t.id;
    o["text"]           = t.text;
    o["due"]            = isoLocal(t.due);
    o["done"]           = t.done;
    o["source"]         = t.source;
    o["last_edited_by"] = t.lastEditedBy;
    return o;
}

// Tool descriptors registered with tools/list.
QJsonArray toolSchemas() {
    auto mkProp = [](const char* type, const char* description) {
        QJsonObject o;
        o["type"] = type;
        o["description"] = description;
        return o;
    };
    auto mkTool = [](const char* name, const char* desc,
                     const QJsonObject& props, const QJsonArray& required) {
        QJsonObject schema;
        schema["type"] = "object";
        schema["properties"] = props;
        schema["required"] = required;
        QJsonObject tool;
        tool["name"] = name;
        tool["description"] = desc;
        tool["inputSchema"] = schema;
        return tool;
    };

    QJsonArray tools;

    // list_events
    {
        QJsonObject p;
        p["from_iso"] = mkProp("string", "Inclusive ISO 8601 lower bound");
        p["to_iso"]   = mkProp("string", "Exclusive ISO 8601 upper bound");
        tools.append(mkTool("list_events",
            "List calendar events overlapping [from_iso, to_iso). Returns JSON array.",
            p, {"from_iso", "to_iso"}));
    }
    // create_event
    {
        QJsonObject p;
        p["title"]     = mkProp("string", "Event title");
        p["start_iso"] = mkProp("string", "ISO 8601 start (local time)");
        p["end_iso"]   = mkProp("string", "ISO 8601 end (local time)");
        p["category"]  = mkProp("string", "Optional category tag");
        tools.append(mkTool("create_event",
            "Create a new event. Marked as agent-sourced for UI source-tinting. Returns the created event including its id.",
            p, {"title", "start_iso", "end_iso"}));
    }
    // update_event
    {
        QJsonObject p;
        p["id"]        = mkProp("integer", "Event id");
        p["title"]     = mkProp("string",  "New title (optional)");
        p["start_iso"] = mkProp("string",  "New ISO start (optional)");
        p["end_iso"]   = mkProp("string",  "New ISO end (optional)");
        p["category"]  = mkProp("string",  "New category (optional)");
        tools.append(mkTool("update_event",
            "Partially update an existing event by id. Omitted fields are preserved.",
            p, {"id"}));
    }
    // delete_event
    {
        QJsonObject p;
        p["id"] = mkProp("integer", "Event id");
        tools.append(mkTool("delete_event", "Delete an event by id.", p, {"id"}));
    }
    // list_tasks
    {
        QJsonObject p;
        tools.append(mkTool("list_tasks", "List all tasks. Returns JSON array.", p, {}));
    }
    // create_task
    {
        QJsonObject p;
        p["text"]    = mkProp("string", "Task text");
        p["due_iso"] = mkProp("string", "Optional ISO due time");
        tools.append(mkTool("create_task",
            "Create a new task. Marked as agent-sourced.",
            p, {"text"}));
    }
    // update_task
    {
        QJsonObject p;
        p["id"]      = mkProp("integer", "Task id");
        p["text"]    = mkProp("string",  "New text (optional)");
        p["due_iso"] = mkProp("string",  "New ISO due (optional, empty string clears)");
        tools.append(mkTool("update_task", "Partially update a task by id.", p, {"id"}));
    }
    // set_task_done
    {
        QJsonObject p;
        p["id"]   = mkProp("integer", "Task id");
        p["done"] = mkProp("boolean", "true to mark done, false to mark undone");
        tools.append(mkTool("set_task_done", "Toggle a task's done state.", p, {"id", "done"}));
    }
    // delete_task
    {
        QJsonObject p;
        p["id"] = mkProp("integer", "Task id");
        tools.append(mkTool("delete_task", "Delete a task by id.", p, {"id"}));
    }

    return tools;
}

} // namespace

McpServer::McpServer(EventRepository* events, TaskRepository* tasks)
    : m_events(events), m_tasks(tasks) {}

QJsonObject McpServer::textContent(const QString& s) {
    QJsonObject c;
    c["type"] = "text";
    c["text"] = s;
    return c;
}

QJsonObject McpServer::errorReply(int code, const QString& message, const QJsonValue& id) {
    QJsonObject err;
    err["code"] = code;
    err["message"] = message;
    QJsonObject resp;
    resp["jsonrpc"] = "2.0";
    resp["id"] = id;
    resp["error"] = err;
    return resp;
}

bool McpServer::handleOneLine(const QByteArray& line) {
    if (line.trimmed().isEmpty()) return true;

    QJsonParseError parseErr;
    const QJsonDocument doc = QJsonDocument::fromJson(line, &parseErr);
    if (parseErr.error != QJsonParseError::NoError || !doc.isObject()) {
        const QJsonObject resp = errorReply(-32700, "Parse error", QJsonValue::Null);
        std::fwrite(QJsonDocument(resp).toJson(QJsonDocument::Compact).constData(), 1,
                    QJsonDocument(resp).toJson(QJsonDocument::Compact).size(), stdout);
        std::fputc('\n', stdout);
        std::fflush(stdout);
        return true;
    }

    const QJsonObject req = doc.object();
    const QJsonObject reply = dispatch(req);
    if (!reply.isEmpty()) {
        const QByteArray out = QJsonDocument(reply).toJson(QJsonDocument::Compact);
        std::fwrite(out.constData(), 1, out.size(), stdout);
        std::fputc('\n', stdout);
        std::fflush(stdout);
    }
    return true;
}

QJsonObject McpServer::dispatch(const QJsonObject& req) {
    const QString method = req.value("method").toString();
    const QJsonValue id  = req.value("id");
    const QJsonObject params = req.value("params").toObject();
    const bool isNotification = !req.contains("id");

    QJsonObject result;
    try {
        if (method == "initialize") {
            result = handleInitialize(params);
        } else if (method == "notifications/initialized" || method == "initialized") {
            // Notification — no response.
            return {};
        } else if (method == "tools/list") {
            result = handleToolsList();
        } else if (method == "tools/call") {
            result = handleToolsCall(params);
        } else if (method == "ping") {
            // empty object result per MCP spec.
        } else {
            if (isNotification) return {};
            return errorReply(-32601, "Method not found: " + method, id);
        }
    } catch (const std::exception& e) {
        return errorReply(-32603, QString("Internal error: ") + e.what(), id);
    }

    if (isNotification) return {};
    QJsonObject resp;
    resp["jsonrpc"] = "2.0";
    resp["id"] = id;
    resp["result"] = result;
    return resp;
}

QJsonObject McpServer::handleInitialize(const QJsonObject& /*params*/) {
    QJsonObject capabilities;
    capabilities["tools"] = QJsonObject();

    QJsonObject info;
    info["name"]    = kServerName;
    info["version"] = kServerVersion;

    QJsonObject result;
    result["protocolVersion"] = kProtocolVersion;
    result["capabilities"]    = capabilities;
    result["serverInfo"]      = info;
    return result;
}

QJsonObject McpServer::handleToolsList() {
    QJsonObject result;
    result["tools"] = toolSchemas();
    return result;
}

QJsonObject McpServer::handleToolsCall(const QJsonObject& params) {
    const QString name = params.value("name").toString();
    const QJsonObject args = params.value("arguments").toObject();

    if (name == "list_events")    return toolListEvents(args);
    if (name == "create_event")   return toolCreateEvent(args);
    if (name == "update_event")   return toolUpdateEvent(args);
    if (name == "delete_event")   return toolDeleteEvent(args);
    if (name == "list_tasks")     return toolListTasks(args);
    if (name == "create_task")    return toolCreateTask(args);
    if (name == "update_task")    return toolUpdateTask(args);
    if (name == "set_task_done")  return toolSetTaskDone(args);
    if (name == "delete_task")    return toolDeleteTask(args);

    QJsonObject result;
    result["isError"] = true;
    QJsonArray content;
    content.append(textContent("Unknown tool: " + name));
    result["content"] = content;
    return result;
}

QJsonObject McpServer::toolListEvents(const QJsonObject& args) {
    const QDateTime from = parseIso(args.value("from_iso").toString());
    const QDateTime to   = parseIso(args.value("to_iso").toString());
    QJsonArray arr;
    if (from.isValid() && to.isValid()) {
        for (const Event& e : m_events->inRange(from, to)) arr.append(eventJson(e));
    }
    QJsonObject result;
    QJsonArray content;
    content.append(textContent(QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Indented))));
    result["content"] = content;
    return result;
}

QJsonObject McpServer::toolCreateEvent(const QJsonObject& args) {
    Event e;
    e.title    = args.value("title").toString();
    e.start    = parseIso(args.value("start_iso").toString());
    e.end      = parseIso(args.value("end_iso").toString());
    e.category = args.value("category").toString();
    e.source       = "agent";
    e.createdBy    = "agent";
    e.lastEditedBy = "agent";

    QJsonObject result;
    QJsonArray content;

    if (!e.start.isValid() || !e.end.isValid()) {
        result["isError"] = true;
        content.append(textContent("Invalid start_iso or end_iso (need ISO 8601)"));
        result["content"] = content;
        return result;
    }
    if (e.end <= e.start) e.end = e.start.addSecs(3600);

    const int id = m_events->insert(e);
    if (id <= 0) {
        result["isError"] = true;
        content.append(textContent("DB insert failed"));
        result["content"] = content;
        return result;
    }
    e.id = id;
    content.append(textContent(QString::fromUtf8(QJsonDocument(eventJson(e)).toJson(QJsonDocument::Indented))));
    result["content"] = content;
    return result;
}

QJsonObject McpServer::toolUpdateEvent(const QJsonObject& args) {
    const int id = args.value("id").toInt();
    QJsonObject result;
    QJsonArray content;

    if (id <= 0) {
        result["isError"] = true;
        content.append(textContent("Missing or invalid id"));
        result["content"] = content;
        return result;
    }

    // Fetch existing to merge — wide window covers most realistic cases.
    const QDateTime from = QDateTime::currentDateTime().addYears(-50);
    const QDateTime to   = QDateTime::currentDateTime().addYears(50);
    Event current;
    bool found = false;
    for (const Event& e : m_events->inRange(from, to)) {
        if (e.id == id) { current = e; found = true; break; }
    }
    if (!found) {
        result["isError"] = true;
        content.append(textContent("Event not found"));
        result["content"] = content;
        return result;
    }

    if (args.contains("title"))     current.title    = args.value("title").toString();
    if (args.contains("category"))  current.category = args.value("category").toString();
    if (args.contains("start_iso")) {
        QDateTime s = parseIso(args.value("start_iso").toString());
        if (s.isValid()) current.start = s;
    }
    if (args.contains("end_iso")) {
        QDateTime e = parseIso(args.value("end_iso").toString());
        if (e.isValid()) current.end = e;
    }
    current.lastEditedBy = "agent";

    if (!m_events->update(current)) {
        result["isError"] = true;
        content.append(textContent("DB update failed"));
        result["content"] = content;
        return result;
    }
    content.append(textContent(QString::fromUtf8(QJsonDocument(eventJson(current)).toJson(QJsonDocument::Indented))));
    result["content"] = content;
    return result;
}

QJsonObject McpServer::toolDeleteEvent(const QJsonObject& args) {
    const int id = args.value("id").toInt();
    QJsonObject result;
    QJsonArray content;
    const bool ok = id > 0 && m_events->remove(id);
    content.append(textContent(ok ? "ok" : "delete failed"));
    if (!ok) result["isError"] = true;
    result["content"] = content;
    return result;
}

QJsonObject McpServer::toolListTasks(const QJsonObject& /*args*/) {
    QJsonArray arr;
    for (const Task& t : m_tasks->all()) arr.append(taskJson(t));
    QJsonObject result;
    QJsonArray content;
    content.append(textContent(QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Indented))));
    result["content"] = content;
    return result;
}

QJsonObject McpServer::toolCreateTask(const QJsonObject& args) {
    Task t;
    t.text = args.value("text").toString();
    const QString due = args.value("due_iso").toString();
    if (!due.isEmpty()) t.due = parseIso(due);
    t.source       = "agent";
    t.lastEditedBy = "agent";

    QJsonObject result;
    QJsonArray content;
    if (t.text.isEmpty()) {
        result["isError"] = true;
        content.append(textContent("Missing text"));
        result["content"] = content;
        return result;
    }
    const int id = m_tasks->insert(t);
    if (id <= 0) {
        result["isError"] = true;
        content.append(textContent("DB insert failed"));
        result["content"] = content;
        return result;
    }
    t.id = id;
    content.append(textContent(QString::fromUtf8(QJsonDocument(taskJson(t)).toJson(QJsonDocument::Indented))));
    result["content"] = content;
    return result;
}

QJsonObject McpServer::toolUpdateTask(const QJsonObject& args) {
    const int id = args.value("id").toInt();
    QJsonObject result;
    QJsonArray content;
    if (id <= 0) {
        result["isError"] = true;
        content.append(textContent("Missing or invalid id"));
        result["content"] = content;
        return result;
    }

    Task current;
    bool found = false;
    for (const Task& t : m_tasks->all()) {
        if (t.id == id) { current = t; found = true; break; }
    }
    if (!found) {
        result["isError"] = true;
        content.append(textContent("Task not found"));
        result["content"] = content;
        return result;
    }

    if (args.contains("text")) current.text = args.value("text").toString();
    if (args.contains("due_iso")) {
        const QString s = args.value("due_iso").toString();
        current.due = s.isEmpty() ? QDateTime() : parseIso(s);
    }
    current.lastEditedBy = "agent";
    if (!m_tasks->update(current)) {
        result["isError"] = true;
        content.append(textContent("DB update failed"));
        result["content"] = content;
        return result;
    }
    content.append(textContent(QString::fromUtf8(QJsonDocument(taskJson(current)).toJson(QJsonDocument::Indented))));
    result["content"] = content;
    return result;
}

QJsonObject McpServer::toolSetTaskDone(const QJsonObject& args) {
    const int id = args.value("id").toInt();
    const bool done = args.value("done").toBool();
    QJsonObject result;
    QJsonArray content;
    const bool ok = id > 0 && m_tasks->setDone(id, done);
    content.append(textContent(ok ? "ok" : "setDone failed"));
    if (!ok) result["isError"] = true;
    result["content"] = content;
    return result;
}

QJsonObject McpServer::toolDeleteTask(const QJsonObject& args) {
    const int id = args.value("id").toInt();
    QJsonObject result;
    QJsonArray content;
    const bool ok = id > 0 && m_tasks->remove(id);
    content.append(textContent(ok ? "ok" : "delete failed"));
    if (!ok) result["isError"] = true;
    result["content"] = content;
    return result;
}

} // namespace dias
