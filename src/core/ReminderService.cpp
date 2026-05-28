#include "ReminderService.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QDateTime>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>

namespace dias {

namespace {
constexpr int kSnoozeMinutes = 10;
}

ReminderService::ReminderService(EventRepository* events, QObject* parent)
    : QObject(parent), m_events(events) {
    // Listen for action invocations and notification close events from the
    // freedesktop Notifications daemon.
    auto bus = QDBusConnection::sessionBus();
    bus.connect("org.freedesktop.Notifications",
                "/org/freedesktop/Notifications",
                "org.freedesktop.Notifications",
                "ActionInvoked",
                this, SLOT(onActionInvoked(uint, QString)));
    bus.connect("org.freedesktop.Notifications",
                "/org/freedesktop/Notifications",
                "org.freedesktop.Notifications",
                "NotificationClosed",
                this, SLOT(onNotificationClosed(uint, uint)));
}

bool ReminderService::dbusAvailable() const {
    return QDBusConnection::sessionBus().isConnected();
}

void ReminderService::start(int pollMs) {
    if (!m_timer) {
        m_timer = new QTimer(this);
        connect(m_timer, &QTimer::timeout, this, &ReminderService::tick);
    }
    tick();
    m_timer->start(pollMs);
}

void ReminderService::stop() {
    if (m_timer) m_timer->stop();
}

void ReminderService::tick() {
    if (!dbusAvailable()) return;

    const QDateTime now = QDateTime::currentDateTime();
    const qint64 nowS = now.toSecsSinceEpoch();
    const QDateTime horizon = now.addDays(1).addSecs(60);
    const auto events = m_events->inRange(now.addDays(-1), horizon);

    for (const Event& e : events) {
        if (e.reminderMinutes <= 0) continue;
        const QString key = QString::number(e.id) + ":" + QString::number(e.start.toSecsSinceEpoch());

        // If this key is snoozed, fire when snooze elapses (regardless of original reminder).
        const qint64 snoozedUntil = m_snoozedUntil.value(key, 0);
        if (snoozedUntil > 0) {
            if (nowS < snoozedUntil) continue;
            // snooze elapsed → fire
            m_snoozedUntil.remove(key);
            QString body = QString("Starts %1 (snoozed)").arg(e.start.toString("HH:mm"));
            if (!e.location.isEmpty()) body += "\n" + e.location;
            fire(e.id, e.title.isEmpty() ? QStringLiteral("(untitled)") : e.title, body);
            continue;
        }

        const QDateTime fireAt = e.start.addSecs(-int(e.reminderMinutes) * 60);
        if (now < fireAt) continue;
        if (e.start <= now) continue;
        if (m_fired.contains(key)) continue;

        const int minsToStart = static_cast<int>(now.secsTo(e.start) / 60);
        QString body = QString("Starts in %1 min — %2").arg(minsToStart).arg(e.start.toString("HH:mm"));
        if (!e.location.isEmpty()) body += "\n" + e.location;

        const quint32 nid = fire(e.id, e.title.isEmpty() ? QStringLiteral("(untitled)") : e.title, body);
        if (nid > 0) m_notifKey.insert(nid, key);
        m_fired.insert(key, true);
    }

    if (m_fired.size() > 500) m_fired.clear();
    if (m_notifKey.size() > 200) m_notifKey.clear();
}

quint32 ReminderService::fire(int /*eventId*/, const QString& title, const QString& body) {
    QDBusInterface notify(
        "org.freedesktop.Notifications",
        "/org/freedesktop/Notifications",
        "org.freedesktop.Notifications",
        QDBusConnection::sessionBus()
    );
    if (!notify.isValid()) return 0;

    QStringList actions;
    actions << "snooze"  << "Snooze 10 min"
            << "dismiss" << "Dismiss";

    QDBusReply<quint32> reply = notify.call("Notify",
        QString("Dias"),
        quint32(0),
        QString("appointment-soon"),  // standard fdo icon name
        title,
        body,
        actions,
        QVariantMap(),
        qint32(12000)
    );
    return reply.isValid() ? reply.value() : 0;
}

void ReminderService::onActionInvoked(quint32 notifId, const QString& actionKey) {
    const QString key = m_notifKey.value(notifId);
    if (key.isEmpty()) return;
    if (actionKey == "snooze") {
        m_snoozedUntil.insert(key, QDateTime::currentSecsSinceEpoch() + kSnoozeMinutes * 60);
        m_fired.remove(key);
    }
    // "dismiss" or anything else → leave m_fired alone so it doesn't re-fire
}

void ReminderService::onNotificationClosed(quint32 notifId, quint32 /*reason*/) {
    m_notifKey.remove(notifId);
}

} // namespace dias
