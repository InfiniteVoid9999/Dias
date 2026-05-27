#pragma once

#include "Task.h"

#include <QVector>
#include <QtSql/QSqlDatabase>

namespace dias {

class TaskRepository {
public:
    explicit TaskRepository(QSqlDatabase db);

    int insert(const Task& t);
    bool update(const Task& t);
    bool remove(int id);
    bool setDone(int id, bool done);
    QVector<Task> all() const;

private:
    QSqlDatabase m_db;
};

} // namespace dias
