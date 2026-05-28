#pragma once

#include "core/Event.h"
#include "core/EventRepository.h"

#include <QAbstractListModel>
#include <QDateTime>
#include <QHash>
#include <QSet>
#include <QVariantList>
#include <QVector>

QT_FORWARD_DECLARE_CLASS(QTimer)

namespace dias {

class EventListModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QDateTime viewStart READ viewStart WRITE setViewStart NOTIFY viewStartChanged)
    Q_PROPERTY(int viewDays READ viewDays WRITE setViewDays NOTIFY viewDaysChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        TitleRole,
        StartRole,
        EndRole,
        AllDayRole,
        CategoryRole,
        SourceRole,
        AgentRecentRole,
        LastEditedByRole,
        RruleRole,
        NotesRole,
        LocationRole,
        ReminderRole,
        LaneRole,
        LanesRole,
        CalendarIdRole,
        CalendarColorRole,
    };

    explicit EventListModel(EventRepository* repo, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QDateTime viewStart() const { return m_viewStart; }
    void setViewStart(const QDateTime& d);

    int viewDays() const { return m_viewDays; }
    void setViewDays(int n);

    Q_INVOKABLE void reload();
    Q_INVOKABLE void createEvent(const QString& title, const QDateTime& start,
                                 const QDateTime& end, const QString& category,
                                 const QString& rrule = {},
                                 bool allDay = false,
                                 const QString& notes = {},
                                 const QString& location = {},
                                 int reminderMinutes = 0,
                                 int calendarId = 1);
    Q_INVOKABLE void updateEvent(int id, const QString& title, const QDateTime& start,
                                 const QDateTime& end, const QString& category,
                                 const QString& rrule = {},
                                 bool allDay = false,
                                 const QString& notes = {},
                                 const QString& location = {},
                                 int reminderMinutes = 0,
                                 int calendarId = 1);
    // Lightweight drag/resize updates that don't require the full payload.
    Q_INVOKABLE void moveEvent(int id, const QDateTime& newStart);
    Q_INVOKABLE void resizeEvent(int id, const QDateTime& newEnd);
    Q_INVOKABLE void removeEvent(int id);

    // Calendar visibility filter — set from CalendarListModel.visibleIdList().
    Q_INVOKABLE void setVisibleCalendarIds(const QVariantList& ids);
    // Per-calendar color lookup hook (called from C++ side by the host).
    void setCalendarColorLookup(class CalendarListModel* m) { m_calendars = m; }
    // Undo hook — when present, mutations record reversible operations.
    void setUndoService(class UndoService* u) { m_undoService = u; }

    // Search returns up to 25 matches as JS-friendly QVariantMaps for popup display.
    Q_INVOKABLE QVariantList search(const QString& q);

    // Position of an all-day event among visible all-day events (-1 if not).
    // Used by WeekView's all-day banner to stack rows tightly without gaps.
    Q_INVOKABLE int allDayPositionOf(int eventId) const;
    Q_INVOKABLE int visibleAllDayCount() const;

    // Per-day-column overlap lane layout: returns the lane index (0-based) and
    // total lane count for an event id within its day column. Used by WeekView
    // to lay overlapping events side-by-side instead of on top of each other.
    Q_INVOKABLE QVariantMap overlapLane(int eventId) const;

    // Polling: refresh from DB every interval; emits agentEditDetected when
    // an external writer (MCP, sync) has touched rows since the last reload.
    Q_INVOKABLE void startPolling(int intervalMs);
    Q_INVOKABLE void stopPolling();

signals:
    void viewStartChanged();
    void viewDaysChanged();
    void agentEditDetected();

private:
    EventRepository* m_repo;
    QDateTime m_viewStart;
    int m_viewDays = 7;
    QVector<Event> m_events;
    qint64 m_lastReloadSec = 0;
    QHash<int, qint64> m_recentAgentIds;  // id -> updated_at
    QHash<int, int>    m_laneOf;          // id -> lane index (precomputed at reload)
    QHash<int, int>    m_lanesOf;         // id -> total lanes in its cluster
    QString            m_lastDataKey;     // diff key to skip no-op reloads
    QSet<int>          m_visibleCalendarIds;
    bool               m_visibilityFilterSet = false;
    class CalendarListModel* m_calendars = nullptr;  // non-owning, for color lookup
    class UndoService*       m_undoService = nullptr;
    QTimer* m_pollTimer = nullptr;
};

} // namespace dias
