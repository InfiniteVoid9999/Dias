#include "Database.h"

#include <QDebug>
#include <QDir>
#include <QStandardPaths>
#include <QtSql/QSqlError>
#include <QtSql/QSqlQuery>

namespace dias {

namespace {

constexpr int kCurrentSchemaVersion = 3;

const char* kSchemaV1 = R"sql(
CREATE TABLE events (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    title           TEXT    NOT NULL,
    start_ts        INTEGER NOT NULL,
    end_ts          INTEGER NOT NULL,
    all_day         INTEGER NOT NULL DEFAULT 0,
    category        TEXT,
    source          TEXT    NOT NULL DEFAULT 'local',
    created_by      TEXT    NOT NULL DEFAULT 'local',
    last_edited_by  TEXT    NOT NULL DEFAULT 'local',
    rrule           TEXT,
    created_at      INTEGER NOT NULL,
    updated_at      INTEGER NOT NULL
);

CREATE INDEX idx_events_range ON events(start_ts, end_ts);
CREATE INDEX idx_events_source ON events(source);

CREATE TABLE tasks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    text        TEXT    NOT NULL,
    due_ts      INTEGER,
    done        INTEGER NOT NULL DEFAULT 0,
    created_at  INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL
);

CREATE INDEX idx_tasks_due ON tasks(due_ts) WHERE due_ts IS NOT NULL;
CREATE INDEX idx_tasks_done ON tasks(done);

CREATE TABLE sync_sources (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    source_type     TEXT    NOT NULL,
    origin_id       TEXT    NOT NULL,
    local_event_id  INTEGER REFERENCES events(id) ON DELETE CASCADE,
    last_pulled_ts  INTEGER,
    UNIQUE(source_type, origin_id)
);
)sql";

const char* kSchemaV2 = R"sql(
ALTER TABLE tasks ADD COLUMN source         TEXT NOT NULL DEFAULT 'local';
ALTER TABLE tasks ADD COLUMN last_edited_by TEXT NOT NULL DEFAULT 'local';
ALTER TABLE tasks ADD COLUMN priority       INTEGER NOT NULL DEFAULT 0;
ALTER TABLE tasks ADD COLUMN status         TEXT NOT NULL DEFAULT 'open';
)sql";

const char* kSchemaV3 = R"sql(
ALTER TABLE events ADD COLUMN notes            TEXT NOT NULL DEFAULT '';
ALTER TABLE events ADD COLUMN location         TEXT NOT NULL DEFAULT '';
ALTER TABLE events ADD COLUMN reminder_minutes INTEGER NOT NULL DEFAULT 0;
)sql";

} // namespace

Database::Database(QString path) : m_path(std::move(path)) {}

Database::~Database() {
    if (m_db.isOpen()) {
        m_db.close();
    }
}

QString Database::defaultPath() {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + "/dias.db";
}

bool Database::open() {
    m_db = QSqlDatabase::addDatabase("QSQLITE", "dias-main");
    m_db.setDatabaseName(m_path);
    if (!m_db.open()) {
        qCritical() << "Database open failed:" << m_db.lastError().text();
        return false;
    }

    QSqlQuery q(m_db);
    // WAL: UI, sync worker, and (future) MCP server all share this DB. WAL keeps
    // readers unblocked while a writer holds the lock — critical for the agent-writer spine.
    for (const char* sql : {
             "PRAGMA journal_mode = WAL",
             "PRAGMA synchronous = NORMAL",
             "PRAGMA foreign_keys = ON",
             "PRAGMA busy_timeout = 5000",
         }) {
        if (!q.exec(sql)) {
            qWarning() << "PRAGMA failed:" << sql << q.lastError().text();
        }
    }

    migrate();
    return true;
}

int Database::userVersion() const {
    QSqlQuery q(m_db);
    q.exec("PRAGMA user_version");
    return q.next() ? q.value(0).toInt() : 0;
}

void Database::setUserVersion(int v) {
    QSqlQuery q(m_db);
    q.exec(QString("PRAGMA user_version = %1").arg(v));
}

void Database::migrate() {
    const int from = userVersion();
    if (from >= kCurrentSchemaVersion) return;

    m_db.transaction();
    auto runScript = [&](const char* sql, int version) -> bool {
        QSqlQuery q(m_db);
        for (const QString& stmt : QString::fromUtf8(sql).split(';', Qt::SkipEmptyParts)) {
            const QString trimmed = stmt.trimmed();
            if (trimmed.isEmpty()) continue;
            if (!q.exec(trimmed)) {
                qCritical() << "Migration v" << version << " failed:" << q.lastError().text()
                            << "stmt:" << trimmed;
                m_db.rollback();
                return false;
            }
        }
        return true;
    };

    if (from < 1) { if (!runScript(kSchemaV1, 1)) return; }
    if (from < 2) { if (!runScript(kSchemaV2, 2)) return; }
    if (from < 3) { if (!runScript(kSchemaV3, 3)) return; }

    setUserVersion(kCurrentSchemaVersion);
    m_db.commit();
    qInfo() << "Database at schema v" << kCurrentSchemaVersion;
}

} // namespace dias
