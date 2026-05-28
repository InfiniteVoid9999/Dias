#include "CalendarRepository.h"

#include <QDateTime>
#include <QDebug>
#include <QtSql/QSqlError>
#include <QtSql/QSqlQuery>

namespace dias {

CalendarRepository::CalendarRepository(QSqlDatabase db) : m_db(std::move(db)) {}

int CalendarRepository::insert(const Calendar& c) {
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO calendars (name, color, visible, created_at)
        VALUES (:name, :color, :visible, :ts)
    )");
    q.bindValue(":name",    c.name);
    q.bindValue(":color",   c.color);
    q.bindValue(":visible", c.visible ? 1 : 0);
    q.bindValue(":ts",      QDateTime::currentSecsSinceEpoch());
    if (!q.exec()) {
        qWarning() << "Calendar insert failed:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool CalendarRepository::update(const Calendar& c) {
    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE calendars SET name = :name, color = :color, visible = :visible
        WHERE id = :id
    )");
    q.bindValue(":name",    c.name);
    q.bindValue(":color",   c.color);
    q.bindValue(":visible", c.visible ? 1 : 0);
    q.bindValue(":id",      c.id);
    if (!q.exec()) { qWarning() << "Calendar update failed:" << q.lastError().text(); return false; }
    return q.numRowsAffected() > 0;
}

bool CalendarRepository::remove(int id) {
    if (id == 1) return false;  // never delete the default Personal calendar
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM calendars WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) { qWarning() << "Calendar remove failed:" << q.lastError().text(); return false; }
    return q.numRowsAffected() > 0;
}

bool CalendarRepository::setVisible(int id, bool visible) {
    QSqlQuery q(m_db);
    q.prepare("UPDATE calendars SET visible = :v WHERE id = :id");
    q.bindValue(":v", visible ? 1 : 0);
    q.bindValue(":id", id);
    if (!q.exec()) { qWarning() << "Calendar setVisible failed:" << q.lastError().text(); return false; }
    return q.numRowsAffected() > 0;
}

QVector<Calendar> CalendarRepository::all() const {
    QSqlQuery q(m_db);
    q.prepare("SELECT id, name, color, visible, created_at FROM calendars ORDER BY id ASC");
    QVector<Calendar> out;
    if (!q.exec()) { qWarning() << "Calendar all() failed:" << q.lastError().text(); return out; }
    while (q.next()) {
        Calendar c;
        c.id        = q.value(0).toInt();
        c.name      = q.value(1).toString();
        c.color     = q.value(2).toString();
        c.visible   = q.value(3).toInt() != 0;
        c.createdAt = q.value(4).toLongLong();
        out.push_back(std::move(c));
    }
    return out;
}

QVector<int> CalendarRepository::visibleIds() const {
    QSqlQuery q(m_db);
    q.prepare("SELECT id FROM calendars WHERE visible = 1");
    QVector<int> out;
    if (!q.exec()) return out;
    while (q.next()) out.append(q.value(0).toInt());
    return out;
}

} // namespace dias
