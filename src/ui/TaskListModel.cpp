#include "TaskListModel.h"

#include <QTimer>

namespace dias {

TaskListModel::TaskListModel(TaskRepository* repo, QObject* parent)
    : QAbstractListModel(parent), m_repo(repo) {
    m_lastReloadSec = QDateTime::currentSecsSinceEpoch();
    reload();
}

int TaskListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(m_tasks.size());
}

QVariant TaskListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_tasks.size()) return {};
    const Task& t = m_tasks[index.row()];
    switch (role) {
        case IdRole:          return t.id;
        case TextRole:        return t.text;
        case DueRole:         return t.due;
        case HasDueRole:      return t.due.isValid();
        case DoneRole:        return t.done;
        case SourceRole:      return t.source;
        case AgentRecentRole: return m_recentAgentIds.contains(t.id);
        case PriorityRole:    return t.priority;
        case StatusRole:      return t.status;
    }
    return {};
}

QHash<int, QByteArray> TaskListModel::roleNames() const {
    return {
        {IdRole,          "id"},
        {TextRole,        "text"},
        {DueRole,         "due"},
        {HasDueRole,      "hasDue"},
        {DoneRole,        "done"},
        {SourceRole,      "source"},
        {AgentRecentRole, "agentRecent"},
        {PriorityRole,    "priority"},
        {StatusRole,      "status"},
    };
}

void TaskListModel::reload() {
    QVector<Task> fresh = m_repo->all();

    QHash<int, qint64> newRecent;
    bool sawAgentEdit = false;
    for (const Task& t : fresh) {
        const bool agentTouched = t.source == "agent" || t.lastEditedBy == "agent";
        if (agentTouched && t.updatedAt > m_lastReloadSec) {
            newRecent.insert(t.id, t.updatedAt);
            sawAgentEdit = true;
        }
    }

    beginResetModel();
    m_tasks = std::move(fresh);
    m_recentAgentIds = std::move(newRecent);
    endResetModel();

    m_lastReloadSec = QDateTime::currentSecsSinceEpoch();
    if (sawAgentEdit) emit agentEditDetected();
}

void TaskListModel::createTask(const QString& text, const QDateTime& due, int priority) {
    Task t;
    t.text     = text;
    t.due      = due;
    t.priority = priority;
    if (m_repo->insert(t) > 0) reload();
}

void TaskListModel::updateTask(int id, const QString& text, const QDateTime& due, int priority) {
    Task t;
    t.id       = id;
    t.text     = text;
    t.due      = due;
    t.priority = priority;
    for (const Task& cur : m_tasks) {
        if (cur.id == id) { t.done = cur.done; t.status = cur.status; break; }
    }
    if (m_repo->update(t)) reload();
}

void TaskListModel::removeTask(int id) {
    if (m_repo->remove(id)) reload();
}

void TaskListModel::setDone(int id, bool done) {
    if (m_repo->setDone(id, done)) reload();
}

void TaskListModel::setPriority(int id, int priority) {
    for (Task t : m_tasks) {
        if (t.id == id) {
            t.priority = priority;
            if (m_repo->update(t)) reload();
            return;
        }
    }
}

void TaskListModel::startPolling(int intervalMs) {
    if (!m_pollTimer) {
        m_pollTimer = new QTimer(this);
        connect(m_pollTimer, &QTimer::timeout, this, &TaskListModel::reload);
    }
    m_pollTimer->start(intervalMs);
}

void TaskListModel::stopPolling() {
    if (m_pollTimer) m_pollTimer->stop();
}

} // namespace dias
