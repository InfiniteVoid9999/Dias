#pragma once

#include "core/Task.h"
#include "core/TaskRepository.h"

#include <QAbstractListModel>
#include <QDateTime>
#include <QVector>

namespace dias {

class TaskListModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TextRole,
        DueRole,
        HasDueRole,
        DoneRole,
    };

    explicit TaskListModel(TaskRepository* repo, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void reload();
    Q_INVOKABLE void createTask(const QString& text, const QDateTime& due);
    Q_INVOKABLE void updateTask(int id, const QString& text, const QDateTime& due);
    Q_INVOKABLE void removeTask(int id);
    Q_INVOKABLE void setDone(int id, bool done);

private:
    TaskRepository* m_repo;
    QVector<Task> m_tasks;
};

} // namespace dias
