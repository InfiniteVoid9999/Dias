#include "GCalSync.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>

namespace dias {

GCalSync::GCalSync(EventRepository* events, QSqlDatabase db, QObject* parent)
    : QObject(parent), m_events(events), m_db(std::move(db)) {}

QString GCalSync::credentialsPath() const {
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
         + "/Dias/gcal.json";
}

bool GCalSync::isConfigured() const {
    QFile f(credentialsPath());
    if (!f.exists()) return false;
    if (!f.open(QIODevice::ReadOnly)) return false;
    const QByteArray bytes = f.readAll();
    f.close();
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return false;
    const QJsonObject o = doc.object();
    return o.contains("client_id") && o.contains("client_secret")
        && o.contains("refresh_token");
}

QString GCalSync::setupInstructions() const {
    return QStringLiteral(
        "Google Calendar sync is not configured yet.\n\n"
        "To enable:\n"
        "  1. Create a Google Cloud project; enable the Calendar API.\n"
        "  2. Create an OAuth 2.0 Desktop client.\n"
        "  3. Save credentials JSON to:\n"
        "       %1\n"
        "     with keys: client_id, client_secret, refresh_token, calendar_id.\n\n"
        "Once present, this button will pull events tagged source='gcal'."
    ).arg(credentialsPath());
}

QVariantMap GCalSync::ingest() {
    QVariantMap m;
    m["imported"] = 0;
    m["updated"]  = 0;
    m["skipped"]  = 0;

    if (!isConfigured()) {
        m["ok"]    = false;
        m["error"] = setupInstructions();
        return m;
    }

    // The actual HTTPS fetch + RFC 3339 parse + sync_sources upsert is the
    // implementation work that drops in here once credentials are present.
    // See header comment for the data-shape contract.
    m["ok"]    = false;
    m["error"] = "GCal credentials found but fetcher not yet implemented in this build.";
    return m;
}

} // namespace dias
