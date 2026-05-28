#include "EventRepository.h"
#include "RRule.h"

#include <QDebug>
#include <QtSql/QSqlError>
#include <QtSql/QSqlQuery>

#include <algorithm>

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
             created_by, last_edited_by, rrule,
             notes, location, reminder_minutes, calendar_id,
             created_at, updated_at)
        VALUES
            (:title, :start, :end, :all_day, :category, :source,
             :created_by, :last_edited_by, :rrule,
             :notes, :location, :reminder, :calendar,
             :ts, :ts)
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
    q.bindValue(":notes", e.notes);
    q.bindValue(":location", e.location);
    q.bindValue(":reminder", e.reminderMinutes);
    q.bindValue(":calendar", e.calendarId > 0 ? e.calendarId : 1);
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
            title            = :title,
            start_ts         = :start,
            end_ts           = :end,
            all_day          = :all_day,
            category         = :category,
            last_edited_by   = :last_edited_by,
            rrule            = :rrule,
            notes            = :notes,
            location         = :location,
            reminder_minutes = :reminder,
            calendar_id      = :calendar,
            updated_at       = :ts
        WHERE id = :id
    )");
    q.bindValue(":title", e.title);
    q.bindValue(":start", e.start.toSecsSinceEpoch());
    q.bindValue(":end", e.end.toSecsSinceEpoch());
    q.bindValue(":all_day", e.allDay ? 1 : 0);
    q.bindValue(":category", orNull(e.category));
    q.bindValue(":last_edited_by", e.lastEditedBy);
    q.bindValue(":rrule", orNull(e.rrule));
    q.bindValue(":notes", e.notes);
    q.bindValue(":location", e.location);
    q.bindValue(":reminder", e.reminderMinutes);
    q.bindValue(":calendar", e.calendarId > 0 ? e.calendarId : 1);
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

namespace {

Event rowToEvent(QSqlQuery& q) {
    Event e;
    e.id              = q.value(0).toInt();
    e.title           = q.value(1).toString();
    e.start           = QDateTime::fromSecsSinceEpoch(q.value(2).toLongLong());
    e.end             = QDateTime::fromSecsSinceEpoch(q.value(3).toLongLong());
    e.allDay          = q.value(4).toInt() != 0;
    e.category        = q.value(5).toString();
    e.source          = q.value(6).toString();
    e.createdBy       = q.value(7).toString();
    e.lastEditedBy    = q.value(8).toString();
    e.rrule           = q.value(9).toString();
    e.updatedAt       = q.value(10).toLongLong();
    e.notes           = q.value(11).toString();
    e.location        = q.value(12).toString();
    e.reminderMinutes = q.value(13).toInt();
    e.calendarId      = q.value(14).toInt();
    return e;
}

} // namespace

QVector<Event> EventRepository::inRange(const QDateTime& from, const QDateTime& to) const {
    QSqlQuery q(m_db);
    q.prepare(R"(
        SELECT id, title, start_ts, end_ts, all_day, category, source,
               created_by, last_edited_by, rrule, updated_at,
               notes, location, reminder_minutes, calendar_id
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
    while (q.next()) out.push_back(rowToEvent(q));
    return out;
}

QVector<Event> EventRepository::search(const QString& q, int limit) const {
    QVector<Event> out;
    if (q.trimmed().isEmpty()) return out;
    QSqlQuery sql(m_db);
    sql.prepare(R"(
        SELECT id, title, start_ts, end_ts, all_day, category, source,
               created_by, last_edited_by, rrule, updated_at,
               notes, location, reminder_minutes
        FROM events
        WHERE title LIKE :p OR notes LIKE :p OR location LIKE :p OR category LIKE :p
        ORDER BY updated_at DESC
        LIMIT :lim
    )");
    sql.bindValue(":p", "%" + q.trimmed() + "%");
    sql.bindValue(":lim", limit);
    if (!sql.exec()) {
        qWarning() << "Event search failed:" << sql.lastError().text();
        return out;
    }
    while (sql.next()) out.push_back(rowToEvent(sql));
    return out;
}

QVector<Event> EventRepository::expandedInRange(const QDateTime& from, const QDateTime& to) const {
    QVector<Event> out;

    // 1) Non-recurring events overlapping the window — standard query.
    {
        QSqlQuery q(m_db);
        q.prepare(R"(
            SELECT id, title, start_ts, end_ts, all_day, category, source,
                   created_by, last_edited_by, rrule, updated_at,
                   notes, location, reminder_minutes, calendar_id
            FROM events
            WHERE (rrule IS NULL OR rrule = '')
              AND start_ts < :to AND end_ts > :from
            ORDER BY start_ts
        )");
        q.bindValue(":from", from.toSecsSinceEpoch());
        q.bindValue(":to",   to.toSecsSinceEpoch());
        if (q.exec()) {
            while (q.next()) out.push_back(rowToEvent(q));
        } else {
            qWarning() << "Non-recurring range query failed:" << q.lastError().text();
        }
    }

    // 2) Recurring events whose series could touch the window.
    {
        QSqlQuery q(m_db);
        q.prepare(R"(
            SELECT id, title, start_ts, end_ts, all_day, category, source,
                   created_by, last_edited_by, rrule, updated_at,
                   notes, location, reminder_minutes, calendar_id
            FROM events
            WHERE rrule IS NOT NULL AND rrule != '' AND start_ts < :to
        )");
        q.bindValue(":to", to.toSecsSinceEpoch());
        if (!q.exec()) {
            qWarning() << "Recurring range query failed:" << q.lastError().text();
        } else {
            while (q.next()) {
                const Event base = rowToEvent(q);
                const RRule rule = RRule::parse(base.rrule);
                const qint64 durSec = base.start.secsTo(base.end);

                if (!rule.isValid()) {
                    // Unknown rule shape — treat as single occurrence if it overlaps.
                    if (base.end > from && base.start < to) out.push_back(base);
                    continue;
                }
                const QVector<QDateTime> instances = rule.expand(base.start, from, to);
                for (const QDateTime& inst : instances) {
                    Event copy = base;
                    copy.start = inst;
                    copy.end   = inst.addSecs(durSec);
                    out.push_back(copy);
                }
            }
        }
    }

    std::sort(out.begin(), out.end(),
              [](const Event& a, const Event& b) { return a.start < b.start; });
    return out;
}

} // namespace dias
