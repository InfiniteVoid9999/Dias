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
    QVector<Event> inRange(const QDateTime& from, const QDateTime& to) const;

private:
    QSqlDatabase m_db;
};

} // namespace dias
