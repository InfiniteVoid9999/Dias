#pragma once

#include "Event.h"

#include <QVector>
#include <QtSql/QSqlDatabase>

namespace dias {

class EventRepository {
public:
    explicit EventRepository(QSqlDatabase db);

    int insert(const Event& e);
    bool update(const Event& e);
    bool remove(int id);

    // Plain overlap query, no RRULE expansion. Use for export / MCP / sync.
    QVector<Event> inRange(const QDateTime& from, const QDateTime& to) const;

    // Same query plus RRULE expansion for any event with a non-empty rrule.
    // Expanded instances are returned as copies of the parent with start/end
    // shifted; id stays the parent's so click-to-edit opens the series.
    // Display-only per PRD §4.3.
    QVector<Event> expandedInRange(const QDateTime& from, const QDateTime& to) const;

    // Full-text style LIKE search over title/notes/location/category.
    // Returns up to `limit` matches, most recently updated first.
    QVector<Event> search(const QString& q, int limit = 25) const;

private:
    QSqlDatabase m_db;
};

} // namespace dias
