#pragma once

#include "EventRepository.h"

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QtSql/QSqlDatabase>

QT_FORWARD_DECLARE_CLASS(QNetworkAccessManager)

namespace dias {

// Read-only subscription to an .ics calendar feed (webcal/https). Fetches
// the feed, parses VEVENT blocks, imports each as source='ics' with
// sync_sources mapping by UID so re-syncs update in place.
//
// Supports the GCal/Outlook surface area:
//   VEVENT { SUMMARY, DTSTART, DTEND, UID, RRULE, LOCATION, DESCRIPTION }
//   DTSTART/DTEND in YYYYMMDDTHHMMSS[Z] or VALUE=DATE:YYYYMMDD (all-day)
//
// Synchronous API (blocks until fetch completes or times out). Fine for
// MVP — only triggered manually from a header button.
class IcsSync : public QObject {
    Q_OBJECT

public:
    IcsSync(EventRepository* events, QSqlDatabase db, QObject* parent = nullptr);
    ~IcsSync() override;

    // Returns { ok, error, imported, updated, skipped } for QML.
    Q_INVOKABLE QVariantMap ingestUrl(const QString& url, int timeoutMs = 15000);

private:
    QString fetchBlocking(const QString& url, int timeoutMs, QString* errorOut);
    QVariantMap importIcsText(const QString& sourceKey, const QString& ics);

    EventRepository*       m_events;
    QSqlDatabase           m_db;
    QNetworkAccessManager* m_net;
};

} // namespace dias
