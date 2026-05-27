#pragma once

#include "EventRepository.h"
#include "TaskRepository.h"

#include <QObject>
#include <QString>

namespace dias {

class ExportService : public QObject {
    Q_OBJECT

public:
    ExportService(EventRepository* events, TaskRepository* tasks, QObject* parent = nullptr);

    // Returns empty string on success, or an error message.
    Q_INVOKABLE QString exportTo(const QString& dir);
    Q_INVOKABLE QString defaultDir() const;

private:
    EventRepository* m_events;
    TaskRepository* m_tasks;
};

} // namespace dias
