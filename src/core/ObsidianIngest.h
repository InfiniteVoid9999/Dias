#pragma once

#include "EventRepository.h"
#include "TaskRepository.h"

#include <QObject>
#include <QString>
#include <QtSql/QSqlDatabase>

namespace dias {

// Read-only ingestion of an Obsidian vault, per PRD §4.3.
//
// Strategy:
//   - Walk *.md files under the vault root.
//   - Parse YAML frontmatter (between leading `---` fences).
//   - If frontmatter has both `start` and `end` ISO timestamps, import as
//     an event with source='obsidian'. Title falls back to filename stem.
//   - If frontmatter has `due` and `task: true` (or filename matches a
//     task convention), import as a task with source-tracked metadata.
//   - On re-ingest, match by (source='obsidian', origin_id=relative-path)
//     via the sync_sources table — updates in place rather than duplicating.
//
// Does not author into the vault — that's v2 two-way sync (§10.3).
class ObsidianIngest : public QObject {
    Q_OBJECT

public:
    ObsidianIngest(EventRepository* events, TaskRepository* tasks,
                   QSqlDatabase db, QObject* parent = nullptr);

    // Returns empty string on success, error message otherwise.
    // imported/updated counts go to out-params if non-null.
    Q_INVOKABLE QString ingestVault(const QString& vaultPath,
                                    int* importedOut = nullptr,
                                    int* updatedOut = nullptr,
                                    int* skippedOut = nullptr);

    Q_INVOKABLE QString defaultVaultPath() const;

private:
    EventRepository* m_events;
    TaskRepository*  m_tasks;
    QSqlDatabase     m_db;
};

} // namespace dias
