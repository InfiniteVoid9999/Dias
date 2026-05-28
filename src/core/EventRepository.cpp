#include "EventRepository.h"

#include <QDebug>
#include <QtSql/QSqlError>
#include <QtSql/QSqlQuery>

namespace dias {

namespace {

qint64 nowSec() { return QDateTime::currentSecsSinceEpoch(); }

QVariant orNull(const QString& s) {
    return s.isEmpty() ? QVariant(QMetaType(QMetaType::QString)) : QVariant(s);
}

} // namespace

EventRepository::EventRepository(QSqlDatabase db) : m_db(std::move(db)) {}

int EventRepository::insert(const Event& e) {
    QSqlQuery q(m_db);
    q.prepare(R"(
        INSERT INTO events
            (title, start_ts, end_ts, all_day, category, source,
             created_by, last_edited_by, rrule, created_at, updated_at)
        VALUES
            (:title, :start, :end, :all_day, :category, :source,
             :created_by, :last_edited_by, :rrule, :ts, :ts)
    )");
    const qint64 ts = nowSec();
    q.bindValue(":title", e.title);
    q.bindValue(":start", e.start.toSecsSinceEpoch());
    q.bindValue(":end", e.end.toSecsSinceEpoch());
    q.bindValue(":all_day", e.allDay ? 1 : 0);
    q.bindValue(":category", orNull(e.category));
    q.bindValue(":source", e.source);
    q.bindValue(":created_by", e.createdBy);
    q.bindValue(":last_edited_by", e.lastEditedBy);
    q.bindValue(":rrule", orNull(e.rrule));
    q.bindValue(":ts", ts);
    if (!q.exec()) {
        qWarning() << "Event insert failed:" << q.lastError().text();
        return -1;
    }
    return q.lastInsertId().toInt();
}

bool EventRepository::update(const Event& e) {
    QSqlQuery q(m_db);
    q.prepare(R"(
        UPDATE events SET
            title          = :title,
            start_ts       = :start,
            end_ts         = :end,
            all_day        = :all_day,
            category       = :category,
            last_edited_by = :last_edited_by,
            updated_at     = :ts
        WHERE id = :id
    )");
    q.bindValue(":title", e.title);
    q.bindValue(":start", e.start.toSecsSinceEpoch());
    q.bindValue(":end", e.end.toSecsSinceEpoch());
    q.bindValue(":all_day", e.allDay ? 1 : 0);
    q.bindValue(":category", orNull(e.category));
    q.bindValue(":last_edited_by", e.lastEditedBy);
    q.bindValue(":ts", nowSec());
    q.bindValue(":id", e.id);
    if (!q.exec()) {
        qWarning() << "Event update failed:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

bool EventRepository::remove(int id) {
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM events WHERE id = :id");
    q.bindValue(":id", id);
    if (!q.exec()) {
        qWarning() << "Event remove failed:" << q.lastError().text();
        return false;
    }
    return q.numRowsAffected() > 0;
}

QVector<Event> EventRepository::inRange(const QDateTime& from, const QDateTime& to) const {
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, title, start_ts, end_ts, all_day, category, source,
               created_by, last_edited_by, rrule, updated_at
        FROM events
        WHERE start_ts < :to AND end_ts > :from
        ORDER BY start_ts
    )");
    q.bindValue(":from", from.toSecsSinceEpoch());
    q.bindValue(":to", to.toSecsSinceEpoch());

    QVector<Event> out;
    if (!q.exec()) {
        qWarning() << "Event range query failed:" << q.lastError().text();
        return out;
    }
    while (q.next()) {
        Event e;
        e.id           = q.value(0).toInt();
        e.title        = q.value(1).toString();
        e.start        = QDateTime::fromSecsSinceEpoch(q.value(2).toLongLong());
        e.end          = QDateTime::fromSecsSinceEpoch(q.value(3).toLongLong());
        e.allDay       = q.value(4).toInt() != 0;
        e.category     = q.value(5).toString();
        e.source       = q.value(6).toString();
        e.createdBy    = q.value(7).toString();
        e.lastEditedBy = q.value(8).toString();
        e.rrule        = q.value(9).toString();
        e.updatedAt    = q.value(10).toLongLong();
        out.push_back(std::move(e));
    }
    return out;
}

} // namespace dias
