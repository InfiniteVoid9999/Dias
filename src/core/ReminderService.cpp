#include "ReminderService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDateTime>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>

namespace dias {

ReminderService::ReminderService(EventRepository* events, QObject* parent)
    : QObject(parent), m_events(events) {}

bool ReminderService::dbusAvailable() const {
    return QDBusConnection::sessionBus().isConnected();
}

void ReminderService::start(int pollMs) {
    if (!m_timer) {
        m_timer = new QTimer(this);
        connect(m_timer, &QTimer::timeout, this, &ReminderService::tick);
    }
    tick();  // immediate check
    m_timer->start(pollMs);
}

void ReminderService::stop() {
    if (m_timer) m_timer->stop();
}

void ReminderService::tick() {
    if (!dbusAvailable()) return;

    const QDateTime now = QDateTime::currentDateTime();
    // Look one day ahead — covers up to "1 day before" reminders.
    const QDateTime horizon = now.addDays(1).addSecs(60);
    const auto events = m_events->inRange(now.addDays(-1), horizon);

    for (const Event& e : events) {
        if (e.reminderMinutes <= 0) continue;
        const QDateTime fireAt = e.start.addSecs(-int(e.reminderMinutes) * 60);
        if (now < fireAt) continue;
        if (e.start <= now) continue;  // event already happening / past

        const QString key = QString::number(e.id) + ":" + QString::number(e.start.toSecsSinceEpoch());
        if (m_fired.contains(key)) continue;

        QString body;
        const int minsToStart = static_cast<int>(now.secsTo(e.start) / 60);
        body = QString("Starts in %1 min — %2")
                 .arg(minsToStart)
                 .arg(e.start.toString("HH:mm"));
        if (!e.location.isEmpty()) body += "\n" + e.location;

        fire(e.title.isEmpty() ? QStringLiteral("(untitled)") : e.title, body);
        m_fired.insert(key, true);
    }

    // Prune old fired keys to bound memory.
    if (m_fired.size() > 500) m_fired.clear();
}

void ReminderService::fire(const QString& title, const QString& body) {
    QDBusInterface notify(
        "org.freedesktop.Notifications",
        "/org/freedesktop/Notifications",
        "org.freedesktop.Notifications",
        QDBusConnection::sessionBus()
    );
    if (!notify.isValid()) return;
    notify.call("Notify",
        QString("Dias"),         // app_name
        quint32(0),              // replaces_id
        QString("calendar"),     // app_icon (theme name)
        title,                   // summary
        body,                    // body
        QStringList(),           // actions
        QVariantMap(),           // hints
        qint32(8000)             // timeout ms
    );
}

} // namespace dias
