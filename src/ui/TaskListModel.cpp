#include "TaskListModel.h"

namespace dias {

TaskListModel::TaskListModel(TaskRepository* repo, QObject* parent)
    : QAbstractListModel(parent), m_repo(repo) {
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
        case IdRole:     return t.id;
        case TextRole:   return t.text;
        case DueRole:    return t.due;
        case HasDueRole: return t.due.isValid();
        case DoneRole:   return t.done;
    }
    return {};
}

QHash<int, QByteArray> TaskListModel::roleNames() const {
    return {
        {IdRole,     "id"},
        {TextRole,   "text"},
        {DueRole,    "due"},
        {HasDueRole, "hasDue"},
        {DoneRole,   "done"},
    };
}

void TaskListModel::reload() {
    beginResetModel();
    m_tasks = m_repo->all();
    endResetModel();
}

void TaskListModel::createTask(const QString& text, const QDateTime& due) {
    Task t;
    t.text = text;
    t.due  = due;
    if (m_repo->insert(t) > 0) reload();
}

void TaskListModel::updateTask(int id, const QString& text, const QDateTime& due) {
    // Preserve done state — pulled from current in-memory snapshot.
    Task t;
    t.id = id;
    t.text = text;
    t.due  = due;
    for (const Task& cur : m_tasks) {
        if (cur.id == id) { t.done = cur.done; break; }
    }
    if (m_repo->update(t)) reload();
}

void TaskListModel::removeTask(int id) {
    if (m_repo->remove(id)) reload();
}

void TaskListModel::setDone(int id, bool done) {
    if (m_repo->setDone(id, done)) reload();
}

} // namespace dias
