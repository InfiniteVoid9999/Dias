#pragma once

#include "core/EventRepository.h"
#include "core/TaskRepository.h"

#include <QByteArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QObject>
#include <QString>

namespace dias {

// Minimal MCP (Model Context Protocol) server over JSON-RPC 2.0 / stdio.
//
// Speaks newline-delimited JSON. Implements just enough of the MCP spec
// (protocolVersion 2024-11-05) to expose calendar CRUD as MCP tools:
//
//   initialize
//   notifications/initialized
//   tools/list
//   tools/call
//
// Tools exposed:
//   list_events    (from_iso, to_iso)
//   create_event   (title, start_iso, end_iso, category?)
//   update_event   (id, title?, start_iso?, end_iso?, category?)
//   delete_event   (id)
//   list_tasks
//   create_task    (text, due_iso?)
//   update_task    (id, text?, due_iso?)
//   set_task_done  (id, done)
//   delete_task    (id)
//
// Every write tags source/created_by/last_edited_by = "agent" so the UI
// can source-tint and pulse to surface agent activity (PRD §7).
class McpServer {
public:
    McpServer(EventRepository* events, TaskRepository* tasks);

    // Read one line, dispatch, write one line. Run in a loop from main.
    // Returns false on EOF / fatal parse error.
    bool handleOneLine(const QByteArray& line);

private:
    QJsonObject dispatch(const QJsonObject& req);
    QJsonObject handleInitialize(const QJsonObject& params);
    QJsonObject handleToolsList();
    QJsonObject handleToolsCall(const QJsonObject& params);

    // Tool implementations — return a "content" array per MCP convention.
    QJsonObject toolListEvents(const QJsonObject& args);
    QJsonObject toolCreateEvent(const QJsonObject& args);
    QJsonObject toolUpdateEvent(const QJsonObject& args);
    QJsonObject toolDeleteEvent(const QJsonObject& args);
    QJsonObject toolSearchEvents(const QJsonObject& args);
    QJsonObject toolListTasks(const QJsonObject& args);
    QJsonObject toolCreateTask(const QJsonObject& args);
    QJsonObject toolUpdateTask(const QJsonObject& args);
    QJsonObject toolSetTaskDone(const QJsonObject& args);
    QJsonObject toolDeleteTask(const QJsonObject& args);

    static QJsonObject textContent(const QString& s);
    static QJsonObject errorReply(int code, const QString& message, const QJsonValue& id);

    EventRepository* m_events;
    TaskRepository*  m_tasks;
};

} // namespace dias
