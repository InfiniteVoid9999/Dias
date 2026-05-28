#pragma once

#include "EventRepository.h"

#include <QHash>
#include <QObject>

QT_FORWARD_DECLARE_CLASS(QTimer)

namespace dias {

// Polls upcoming events and fires desktop notifications via the freedesktop
// Notifications DBus service when an event with reminder_minutes > 0 hits
// its reminder time.
//
// State: an in-memory set of (event_id, start_ts) keys for already-fired
// reminders. Resets when the app restarts — acceptable for MVP (a missed
// reminder during downtime is recoverable; double-firing is not).
class ReminderService : public QObject {
    Q_OBJECT

public:
    explicit ReminderService(EventRepository* events, QObject* parent = nullptr);

    Q_INVOKABLE void start(int pollMs = 30000);
    Q_INVOKABLE void stop();
    Q_INVOKABLE bool dbusAvailable() const;

private:
    void tick();
    void fire(const QString& title, const QString& body);

    EventRepository* m_events;
    QTimer* m_timer = nullptr;
    QHash<QString, bool> m_fired;  // key = id:startTs
};

} // namespace dias
