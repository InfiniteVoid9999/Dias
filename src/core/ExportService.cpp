#include "ExportService.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QTextStream>

namespace dias {

namespace {

QString isoLocal(const QDateTime& dt) {
    return dt.isValid() ? dt.toString(Qt::ISODate) : QString();
}

QJsonObject eventToJson(const Event& e) {
    QJsonObject o;
    o["id"]              = e.id;
    o["title"]           = e.title;
    o["start"]           = isoLocal(e.start);
    o["end"]             = isoLocal(e.end);
    o["all_day"]         = e.allDay;
    o["category"]        = e.category;
    o["source"]          = e.source;
    o["created_by"]      = e.createdBy;
    o["last_edited_by"]  = e.lastEditedBy;
    o["rrule"]           = e.rrule;
    return o;
}

QJsonObject taskToJson(const Task& t) {
    QJsonObject o;
    o["id"]   = t.id;
    o["text"] = t.text;
    o["due"]  = isoLocal(t.due);
    o["done"] = t.done;
    return o;
}

QString slugify(const QString& s) {
    QString out;
    out.reserve(s.size());
    for (QChar c : s) {
        if (c.isLetterOrNumber()) out += c.toLower();
        else if (c.isSpace() || c == '-' || c == '_') out += '-';
    }
    while (out.contains("--")) out.replace("--", "-");
    if (out.startsWith('-')) out.remove(0, 1);
    if (out.endsWith('-')) out.chop(1);
    if (out.isEmpty()) out = "untitled";
    if (out.size() > 60) out = out.left(60);
    return out;
}

bool writeFile(const QString& path, const QByteArray& data) {
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    const qint64 wrote = f.write(data);
    f.close();
    return wrote == data.size();
}

QByteArray buildEventMarkdown(const Event& e) {
    QString s;
    QTextStream ts(&s);
    ts << "---\n";
    ts << "id: "             << e.id << "\n";
    ts << "title: \""        << QString(e.title).replace('"', "\\\"") << "\"\n";
    ts << "start: "          << isoLocal(e.start) << "\n";
    ts << "end: "            << isoLocal(e.end) << "\n";
    ts << "all_day: "        << (e.allDay ? "true" : "false") << "\n";
    if (!e.category.isEmpty())
        ts << "category: \"" << e.category << "\"\n";
    ts << "source: "         << e.source << "\n";
    ts << "created_by: "     << e.createdBy << "\n";
    ts << "last_edited_by: " << e.lastEditedBy << "\n";
    if (!e.rrule.isEmpty())
        ts << "rrule: \""    << e.rrule << "\"\n";
    ts << "tags: [dias, event]\n";
    ts << "---\n\n";
    ts << "# " << (e.title.isEmpty() ? QStringLiteral("(untitled)") : e.title) << "\n";
    return s.toUtf8();
}

QByteArray buildTasksMarkdown(const QVector<Task>& tasks) {
    QString s;
    QTextStream ts(&s);
    ts << "---\n";
    ts << "tags: [dias, tasks]\n";
    ts << "---\n\n";
    ts << "# Tasks\n\n";
    for (const Task& t : tasks) {
        ts << (t.done ? "- [x] " : "- [ ] ") << t.text;
        if (t.due.isValid()) {
            ts << " — due " << t.due.toString("yyyy-MM-dd HH:mm");
        }
        ts << "\n";
    }
    return s.toUtf8();
}

} // namespace

ExportService::ExportService(EventRepository* events, TaskRepository* tasks, QObject* parent)
    : QObject(parent), m_events(events), m_tasks(tasks) {}

QString ExportService::defaultDir() const {
    return QDir::homePath() + "/Dias/export";
}

QString ExportService::exportTo(const QString& dir) {
    QDir base(dir);
    if (!base.exists() && !QDir().mkpath(dir)) {
        return QStringLiteral("Could not create %1").arg(dir);
    }
    const QString eventsDir = dir + "/events";
    if (!QDir(eventsDir).exists() && !QDir().mkpath(eventsDir)) {
        return QStringLiteral("Could not create %1").arg(eventsDir);
    }

    // Pull a wide window: ten years either side. MVP scale.
    const QDateTime from = QDateTime::currentDateTime().addYears(-10);
    const QDateTime to   = QDateTime::currentDateTime().addYears(10);
    const QVector<Event> events = m_events->inRange(from, to);
    const QVector<Task> tasks   = m_tasks->all();

    QJsonArray eventArr;
    for (const Event& e : events) eventArr.append(eventToJson(e));
    QJsonArray taskArr;
    for (const Task& t : tasks)   taskArr.append(taskToJson(t));

    QJsonObject manifest;
    manifest["exported_at"]  = isoLocal(QDateTime::currentDateTime());
    manifest["schema"]       = 1;
    manifest["event_count"]  = static_cast<int>(events.size());
    manifest["task_count"]   = static_cast<int>(tasks.size());

    if (!writeFile(dir + "/events.json",
                   QJsonDocument(eventArr).toJson(QJsonDocument::Indented))) {
        return QStringLiteral("Failed writing events.json");
    }
    if (!writeFile(dir + "/tasks.json",
                   QJsonDocument(taskArr).toJson(QJsonDocument::Indented))) {
        return QStringLiteral("Failed writing tasks.json");
    }
    if (!writeFile(dir + "/manifest.json",
                   QJsonDocument(manifest).toJson(QJsonDocument::Indented))) {
        return QStringLiteral("Failed writing manifest.json");
    }

    // Clear stale event markdown so deleted events don't linger.
    {
        QDir d(eventsDir);
        const QStringList stale = d.entryList({"*.md"}, QDir::Files);
        for (const QString& f : stale) QFile::remove(eventsDir + "/" + f);
    }

    for (const Event& e : events) {
        const QString datePart = e.start.toString("yyyy-MM-dd");
        const QString path = QStringLiteral("%1/%2-%3-%4.md")
                                .arg(eventsDir, datePart, slugify(e.title))
                                .arg(e.id);
        if (!writeFile(path, buildEventMarkdown(e))) {
            return QStringLiteral("Failed writing %1").arg(path);
        }
    }

    if (!writeFile(dir + "/tasks.md", buildTasksMarkdown(tasks))) {
        return QStringLiteral("Failed writing tasks.md");
    }

    return {};
}

} // namespace dias
