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
    QString notes;
    QString location;
    int reminderMinutes = 0;
    int calendarId = 1;  // FK → calendars.id; default Personal
    qint64 updatedAt = 0;
};

} // namespace dias
