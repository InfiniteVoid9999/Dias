#pragma once

#include "Calendar.h"

#include <QVector>
#include <QtSql/QSqlDatabase>

namespace dias {

class CalendarRepository {
public:
    explicit CalendarRepository(QSqlDatabase db);

    int  insert(const Calendar& c);
    bool update(const Calendar& c);
    bool remove(int id);
    bool setVisible(int id, bool visible);

    QVector<Calendar> all() const;
    QVector<int>      visibleIds() const;

private:
    QSqlDatabase m_db;
};

} // namespace dias
