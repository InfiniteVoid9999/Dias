#pragma once

#include <QDateTime>
#include <QString>

namespace dias {

struct Event {
    int id = 0;
    QString title;
    QDateTime start;
    QDateTime end;
    bool allDay = false;
    QString category;
    QString source = "local";
    QString createdBy = "local";
    QString lastEditedBy = "local";
    QString rrule;
    qint64 updatedAt = 0;  // unix seconds, populated on read
};

} // namespace dias
