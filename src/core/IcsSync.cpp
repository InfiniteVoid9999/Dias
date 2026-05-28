#include "IcsSync.h"

#include <QDateTime>
#include <QDebug>
#include <QEventLoop>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QTimer>
#include <QUrl>
#include <QtSql/QSqlError>
#include <QtSql/QSqlQuery>

namespace dias {

namespace {

QDateTime parseIcsTimestamp(const QString& s, bool& isDateOnly) {
    isDateOnly = false;
    QString clean = s;
    if (clean.endsWith('Z')) clean.chop(1);
    if (clean.length() == 8) {
        isDateOnly = true;
        return QDateTime::fromString(clean, "yyyyMMdd");
    }
    if (clean.length() >= 15 && clean[8] == 'T') {
        return QDateTime::fromString(clean.left(15), "yyyyMMddTHHmmss");
    }
    return {};
}

QString unescapeIcs(const QString& v) {
    QString out = v;
    out.replace("\\n", "\n").replace("\\N", "\n");
    out.replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\");
    return out;
}

// Unfold ICS lines: lines starting with space/tab continue the previous line.
QStringList unfoldLines(const QString& raw) {
    QStringList out;
    const QStringList lines = raw.split(QRegularExpression("\\r?\\n"));
    for (const QString& line : lines) {
        if (!out.isEmpty() && (line.startsWith(' ') || line.startsWith('\t'))) {
            out.last() += line.mid(1);
        } else {
            out.append(line);
        }
    }
    return out;
}

int existingMappedId(QSqlDatabase& db, const QString& sourceType, const QString& originId) {
    QSqlQuery q(db);
    q.prepare("SELECT local_event_id FROM sync_sources WHERE source_type=:s AND origin_id=:o");
    q.bindValue(":s", sourceType);
    q.bindValue(":o", originId);
    if (!q.exec() || !q.next()) return 0;
    return q.value(0).toInt();
}

void upsertMapping(QSqlDatabase& db, const QString& sourceType, const QString& originId, int localEventId) {
    QSqlQuery q(db);
    q.prepare(R"(
        INSERT INTO sync_sources (source_type, origin_id, local_event_id, last_pulled_ts)
        VALUES (:s, :o, :l, :ts)
        ON CONFLICT(source_type, origin_id) DO UPDATE SET
            local_event_id = excluded.local_event_id,
            last_pulled_ts = excluded.last_pulled_ts
    )");
    q.bindValue(":s", sourceType);
    q.bindValue(":o", originId);
    q.bindValue(":l", localEventId);
    q.bindValue(":ts", QDateTime::currentSecsSinceEpoch());
    if (!q.exec()) qWarning() << "IcsSync mapping upsert failed:" << q.lastError().text();
}

} // namespace

IcsSync::IcsSync(EventRepository* events, QSqlDatabase db, QObject* parent)
    : QObject(parent), m_events(events), m_db(std::move(db)),
      m_net(new QNetworkAccessManager(this)) {}

IcsSync::~IcsSync() = default;

QString IcsSync::fetchBlocking(const QString& url, int timeoutMs, QString* errorOut) {
    QUrl qurl(url);
    if (qurl.scheme() == "webcal") qurl.setScheme("https");
    if (!qurl.isValid()) { if (errorOut) *errorOut = "Invalid URL"; return {}; }

    QNetworkRequest req(qurl);
    req.setHeader(QNetworkRequest::UserAgentHeader, "Dias/0.1 (+https://github.com/InfiniteVoid9999/Dias)");
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    QNetworkReply* reply = m_net->get(req);
    QEventLoop loop;
    QTimer timer;
    timer.setSingleShot(true);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QObject::connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
    timer.start(timeoutMs);
    loop.exec();

    if (!timer.isActive()) {
        if (errorOut) *errorOut = "Request timed out";
        reply->abort();
        reply->deleteLater();
        return {};
    }
    timer.stop();

    if (reply->error() != QNetworkReply::NoError) {
        if (errorOut) *errorOut = reply->errorString();
        reply->deleteLater();
        return {};
    }
    const QString body = QString::fromUtf8(reply->readAll());
    reply->deleteLater();
    return body;
}

QVariantMap IcsSync::ingestUrl(const QString& url, int timeoutMs) {
    QVariantMap r;
    r["imported"] = 0; r["updated"] = 0; r["skipped"] = 0;

    QString err;
    const QString ics = fetchBlocking(url, timeoutMs, &err);
    if (!err.isEmpty()) {
        r["ok"] = false;
        r["error"] = "Fetch failed: " + err;
        return r;
    }
    if (ics.isEmpty()) {
        r["ok"] = false;
        r["error"] = "Empty response";
        return r;
    }

    return importIcsText(QUrl(url).host(), ics);
}

QVariantMap IcsSync::importIcsText(const QString& sourceKey, const QString& ics) {
    QVariantMap r;
    int imported = 0, updated = 0, skipped = 0;

    const QStringList lines = unfoldLines(ics);
    bool inEvent = false;
    QString summary, uid, description, location, rrule, dtstartRaw, dtendRaw;
    bool allDay = false;

    auto resetCurrent = [&]() {
        summary.clear(); uid.clear(); description.clear(); location.clear();
        rrule.clear(); dtstartRaw.clear(); dtendRaw.clear(); allDay = false;
    };

    for (const QString& rawLine : lines) {
        QString line = rawLine.trimmed();
        if (line == "BEGIN:VEVENT") { inEvent = true; resetCurrent(); continue; }
        if (line == "END:VEVENT") {
            inEvent = false;
            if (uid.isEmpty()) { ++skipped; continue; }
            bool srcDateOnly = false, endDateOnly = false;
            QDateTime start = parseIcsTimestamp(dtstartRaw, srcDateOnly);
            QDateTime end   = dtendRaw.isEmpty() ? start.addSecs(3600)
                                                 : parseIcsTimestamp(dtendRaw, endDateOnly);
            if (!start.isValid()) { ++skipped; continue; }
            if (!end.isValid()) end = start.addSecs(3600);
            if (srcDateOnly || endDateOnly) allDay = true;

            Event e;
            e.title           = unescapeIcs(summary);
            e.start           = start;
            e.end             = end;
            e.allDay          = allDay;
            e.notes           = unescapeIcs(description);
            e.location        = unescapeIcs(location);
            e.source          = "gcal";   // tinted as gcal — same external-feed vibe
            e.createdBy       = "ics";
            e.lastEditedBy    = "ics";
            e.rrule           = rrule;

            const QString originId = sourceKey + "|" + uid;
            const int existing = existingMappedId(m_db, "ics", originId);
            if (existing > 0) {
                e.id = existing;
                if (m_events->update(e)) ++updated; else ++skipped;
            } else {
                const int newId = m_events->insert(e);
                if (newId > 0) {
                    upsertMapping(m_db, "ics", originId, newId);
                    ++imported;
                } else {
                    ++skipped;
                }
            }
            continue;
        }
        if (!inEvent) continue;

        // KEY[;PARAMS]:VALUE
        const int colon = line.indexOf(':');
        if (colon < 0) continue;
        QString header = line.left(colon);
        QString value  = line.mid(colon + 1);
        const int semi = header.indexOf(';');
        QString key = (semi < 0) ? header : header.left(semi);
        QString params = (semi < 0) ? QString() : header.mid(semi + 1);

        if (key == "SUMMARY")          summary     = value;
        else if (key == "UID")         uid         = value;
        else if (key == "DESCRIPTION") description = value;
        else if (key == "LOCATION")    location    = value;
        else if (key == "RRULE")       rrule       = value;
        else if (key == "DTSTART") {
            dtstartRaw = value;
            if (params.contains("VALUE=DATE", Qt::CaseInsensitive)) allDay = true;
        }
        else if (key == "DTEND") {
            dtendRaw = value;
            if (params.contains("VALUE=DATE", Qt::CaseInsensitive)) allDay = true;
        }
    }

    r["ok"]       = true;
    r["error"]    = QString();
    r["imported"] = imported;
    r["updated"]  = updated;
    r["skipped"]  = skipped;
    return r;
}

} // namespace dias
