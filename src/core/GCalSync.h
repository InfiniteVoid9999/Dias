#pragma once

#include "EventRepository.h"

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QtSql/QSqlDatabase>

namespace dias {

// Google Calendar ingestion (PRD §4.3, §10.2).
//
// This service is INTENTIONALLY non-functional out of the box. Wiring a
// useful OAuth flow requires a Google Cloud project + OAuth client of your
// own (Google forbids shipping app-wide credentials in distributed binaries).
// So instead of a half-working stub that pretends to sign you in, this class
// exposes a clear "isConfigured()" check and a setup instruction string.
//
// To enable later:
//   1. Create a Google Cloud project, enable the Calendar API.
//   2. Create an OAuth 2.0 Desktop client. Note the client_id and secret.
//   3. Save credentials to ~/.config/Dias/gcal.json with shape:
//        {
//          "client_id": "...",
//          "client_secret": "...",
//          "refresh_token": "...",
//          "calendar_id": "primary"
//        }
//      (refresh_token is obtained once via a one-shot CLI flow we'll add
//      alongside the actual fetcher in a follow-up.)
//   4. Implement fetchEvents() to GET
//        https://www.googleapis.com/calendar/v3/calendars/{calendar_id}/events
//      with Authorization: Bearer <access_token>, then map each Google
//      event into a dias::Event (source='gcal'), respecting recurringEventId
//      and originalStartTime for RRULE-instance dedup.
//
// What's already in place to make that drop-in:
//   - sync_sources table maps (source_type='gcal', origin_id=googleEventId)
//     to local_event_id, so update-in-place works out of the box.
//   - Event schema has source/created_by/last_edited_by/rrule columns.
//   - RRule parser handles the FREQ/INTERVAL/BYDAY surface GCal emits.
//   - The UI already source-tints events with source='gcal' (sky/cyan).
class GCalSync : public QObject {
    Q_OBJECT

public:
    GCalSync(EventRepository* events, QSqlDatabase db, QObject* parent = nullptr);

    Q_INVOKABLE bool isConfigured() const;
    Q_INVOKABLE QString credentialsPath() const;
    Q_INVOKABLE QString setupInstructions() const;

    // Returns { ok, error, imported, updated, skipped } shape; until creds
    // are present, ok=false and error explains the setup steps tersely.
    Q_INVOKABLE QVariantMap ingest();

private:
    EventRepository* m_events;
    QSqlDatabase     m_db;
};

} // namespace dias
