#include "ObsidianIngest.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QMap>
#include <QRegularExpression>
#include <QTextStream>
#include <QtSql/QSqlError>
#include <QtSql/QSqlQuery>

namespace dias {

namespace {

// Tiny YAML-like frontmatter parser. Handles only:
//   key: value
//   key: "value with spaces"
//   key: [a, b, c]
// No nested maps. That's the surface area Obsidian users actually use.
QMap<QString, QString> parseFrontmatter(const QString& md) {
    QMap<QString, QString> out;
    if (!md.startsWith("---")) return out;

    int endFence = md.indexOf("\n---", 3);
    if (endFence < 0) return out;
    const QString block = md.mid(3, endFence - 3);

    for (const QString& rawLine : block.split('\n', Qt::SkipEmptyParts)) {
        const QString line = rawLine.trimmed();
        if (line.isEmpty() || line.startsWith('#')) continue;
        const int colon = line.indexOf(':');
        if (colon <= 0) continue;
        QString key = line.left(colon).trimmed().toLower();
        QString val = line.mid(colon + 1).trimmed();
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith('\'') && val.endsWith('\''))) {
            val = val.mid(1, val.length() - 2);
        }
        out[key] = val;
    }
    return out;
}

QDateTime parseLooseDateTime(const QString& s) {
    if (s.isEmpty()) return {};
    // Try ISO with seconds, ISO without seconds, date only.
    QDateTime dt = QDateTime::fromString(s, Qt::ISODate);
    if (dt.isValid()) return dt;
    static const QString fmts[] = {
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-ddTHH:mm",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-ddTHH:mm:ss",
        "yyyy-MM-dd",
    };
    for (const QString& f : fmts) {
        dt = QDateTime::fromString(s, f);
        if (dt.isValid()) return dt;
    }
    return {};
}

bool truthyFlag(const QString& s) {
    const QString lc = s.toLower();
    return lc == "true" || lc == "yes" || lc == "1";
}

// Lookup existing local event id by (source='obsidian', origin_id=relPath).
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
    if (!q.exec()) {
        qWarning() << "ObsidianIngest mapping upsert failed:" << q.lastError().text();
    }
}

} // namespace

ObsidianIngest::ObsidianIngest(EventRepository* events, TaskRepository* tasks,
                               QSqlDatabase db, QObject* parent)
    : QObject(parent), m_events(events), m_tasks(tasks), m_db(std::move(db)) {}

QString ObsidianIngest::defaultVaultPath() const {
    return QDir::homePath() + "/Documents/To Fart or To Shit";
}

QString ObsidianIngest::ingestVault(const QString& vaultPath,
                                     int* importedOut, int* updatedOut, int* skippedOut) {
    int imported = 0, updated = 0, skipped = 0;

    QDir vault(vaultPath);
    if (!vault.exists()) {
        if (skippedOut) *skippedOut = skipped;
        return QStringLiteral("Vault path does not exist: %1").arg(vaultPath);
    }

    QSqlDatabase& db = m_db;

    QDirIterator it(vaultPath, {"*.md"}, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString fullPath = it.next();
        const QString relPath  = vault.relativeFilePath(fullPath);

        QFile f(fullPath);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            ++skipped;
            continue;
        }
        const QString md = QString::fromUtf8(f.readAll());
        f.close();

        const auto front = parseFrontmatter(md);
        if (front.isEmpty()) { ++skipped; continue; }

        const QString startStr = front.value("start");
        const QString endStr   = front.value("end");
        const QString dueStr   = front.value("due");
        const bool isTask      = truthyFlag(front.value("task"));

        if (!startStr.isEmpty() && !endStr.isEmpty()) {
            // Event candidate.
            const QDateTime start = parseLooseDateTime(startStr);
            const QDateTime end   = parseLooseDateTime(endStr);
            if (!start.isValid() || !end.isValid()) { ++skipped; continue; }

            QString title = front.value("title");
            if (title.isEmpty()) title = QFileInfo(fullPath).baseName();

            Event e;
            e.title    = title;
            e.start    = start;
            e.end      = end;
            e.category = front.value("category");
            e.source       = "obsidian";
            e.createdBy    = "obsidian";
            e.lastEditedBy = "obsidian";
            e.rrule        = front.value("rrule");

            const int mappedId = existingMappedId(db, "obsidian", relPath);
            if (mappedId > 0) {
                e.id = mappedId;
                if (m_events->update(e)) ++updated; else ++skipped;
            } else {
                const int newId = m_events->insert(e);
                if (newId > 0) {
                    upsertMapping(db, "obsidian", relPath, newId);
                    ++imported;
                } else {
                    ++skipped;
                }
            }
        } else if (isTask) {
            Task t;
            t.text = front.value("title").isEmpty()
                     ? QFileInfo(fullPath).baseName()
                     : front.value("title");
            t.due = parseLooseDateTime(dueStr);
            t.done = truthyFlag(front.value("done"));
            // Tasks don't have an obsidian-mapping table yet; for MVP just insert.
            // Duplicate-on-reingest is a known limitation; cleanup belongs in a
            // future task-mapping pass.
            if (m_tasks->insert(t) > 0) ++imported;
            else ++skipped;
        } else {
            ++skipped;
        }
    }

    if (importedOut) *importedOut = imported;
    if (updatedOut)  *updatedOut  = updated;
    if (skippedOut)  *skippedOut  = skipped;
    return {};
}

} // namespace dias
