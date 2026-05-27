#include "TaskRepository.h"

#include <QDebug>
#include <QtSql/QSqlError>
#include <QtSql/QSqlQuery>

namespace dias {

namespace {

qint64 nowSec() { return QDateTime::currentSecsSinceEpoch(); }

QVariant dueOrNull(const QDateTime& d) {
    return d.isValid() ? QVariant(d.toSecsSinceEpoch()) : QVariant(QMetaType(QMetaType::LongLong));
}

} // namespace

TaskRepository::TaskRepository(QSqlDatabase db) : m_db(std::move(db)) {}

int TaskRepository::insert(const Task& t) {
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO tasks (text, due_ts, done, created_at, updated_at)
        VALUES (:text, :due, :done, :ts, :ts)
    )");
    const qint64 ts = nowSec();
    q.bindValue(":text", t.text);
    q.bindValue(":due", dueOrNull(t.due));
    q.bindValue(":done", t.done ? 1 : 0);
    q.bindValue(":ts", ts);
    if (!q.exec()) {
        qWarning() << "Task insert failed:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool TaskRepository::update(const Task& t) {
    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE tasks SET
            text = :text,
            due_ts = :due,
            done = :done,
            updated_at = :ts
        WHERE id = :id
    )");
    q.bindValue(":text", t.text);
    q.bindValue(":due", dueOrNull(t.due));
    q.bindValue(":done", t.done ? 1 : 0);
    q.bindValue(":ts", nowSec());
    q.bindValue(":id", t.id);
    if (!q.exec()) {
        qWarning() << "Task update failed:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

bool TaskRepository::remove(int id) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM tasks WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "Task remove failed:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

bool TaskRepository::setDone(int id, bool done) {
    QSqlQuery q(m_db);
    q.prepare("UPDATE tasks SET done = :done, updated_at = :ts WHERE id = :id");
    q.bindValue(":done", done ? 1 : 0);
    q.bindValue(":ts", nowSec());
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "Task setDone failed:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

QVector<Task> TaskRepository::all() const {
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, text, due_ts, done
        FROM tasks
        ORDER BY done ASC,
                 CASE WHEN due_ts IS NULL THEN 1 ELSE 0 END,
                 due_ts ASC,
                 created_at ASC
    )");
    QVector<Task> out;
    if (!q.exec()) {
        qWarning() << "Task all() failed:" << q.lastError().text();
        return out;
    }
    while (q.next()) {
        Task t;
        t.id   = q.value(0).toInt();
        t.text = q.value(1).toString();
        if (!q.value(2).isNull()) {
            t.due = QDateTime::fromSecsSinceEpoch(q.value(2).toLongLong());
        }
        t.done = q.value(3).toInt() != 0;
        out.push_back(std::move(t));
    }
    return out;
}

} // namespace dias
