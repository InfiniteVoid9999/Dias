#include "EventListModel.h"

#include <QTimer>

namespace dias {

EventListModel::EventListModel(EventRepository* repo, QObject* parent)
    : QAbstractListModel(parent), m_repo(repo) {
    // Initialize cutoff to "now" so events from previous sessions don't pulse
    // on first reload after launch.
    m_lastReloadSec = QDateTime::currentSecsSinceEpoch();
}

int EventListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(m_events.size());
}

QVariant EventListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_events.size()) return {};
    const Event& e = m_events[index.row()];
    switch (role) {
        case IdRole:           return e.id;
        case TitleRole:        return e.title;
        case StartRole:        return e.start;
        case EndRole:          return e.end;
        case AllDayRole:       return e.allDay;
        case CategoryRole:     return e.category;
        case SourceRole:       return e.source;
        case LastEditedByRole: return e.lastEditedBy;
        case AgentRecentRole:  return m_recentAgentIds.contains(e.id);
        case RruleRole:        return e.rrule;
        case NotesRole:        return e.notes;
        case LocationRole:     return e.location;
        case ReminderRole:     return e.reminderMinutes;
    }
    return {};
}

QHash<int, QByteArray> EventListModel::roleNames() const {
    return {
        {IdRole,           "id"},
        {TitleRole,        "title"},
        {StartRole,        "start"},
        {EndRole,          "end"},
        {AllDayRole,       "allDay"},
        {CategoryRole,     "category"},
        {SourceRole,       "source"},
        {LastEditedByRole, "lastEditedBy"},
        {AgentRecentRole,  "agentRecent"},
        {RruleRole,        "rrule"},
        {NotesRole,        "notes"},
        {LocationRole,     "location"},
        {ReminderRole,     "reminderMinutes"},
    };
}

void EventListModel::setViewStart(const QDateTime& d) {
    if (m_viewStart == d) return;
    m_viewStart = d;
    emit viewStartChanged();
    reload();
}

void EventListModel::setViewDays(int n) {
    if (n < 1) n = 1;
    if (m_viewDays == n) return;
    m_viewDays = n;
    emit viewDaysChanged();
    reload();
}

void EventListModel::reload() {
    if (!m_viewStart.isValid()) return;

    // expandedInRange returns RRULE-expanded instances for the visible window.
    QVector<Event> fresh = m_repo->expandedInRange(m_viewStart, m_viewStart.addDays(m_viewDays));

    // Detect agent edits since last reload — these get a transient pulse.
    QHash<int, qint64> newRecent;
    bool sawAgentEdit = false;
    for (const Event& e : fresh) {
        const bool agentTouched = e.source == "agent" || e.lastEditedBy == "agent";
        if (agentTouched && e.updatedAt > m_lastReloadSec) {
            newRecent.insert(e.id, e.updatedAt);
            sawAgentEdit = true;
        }
    }

    beginResetModel();
    m_events = std::move(fresh);
    m_recentAgentIds = std::move(newRecent);
    endResetModel();

    m_lastReloadSec = QDateTime::currentSecsSinceEpoch();
    if (sawAgentEdit) emit agentEditDetected();
}

void EventListModel::createEvent(const QString& title, const QDateTime& start,
                                 const QDateTime& end, const QString& category,
                                 const QString& rrule, bool allDay,
                                 const QString& notes, const QString& location,
                                 int reminderMinutes) {
    Event e;
    e.title           = title;
    e.start           = start;
    e.end             = end;
    e.category        = category;
    e.rrule           = rrule;
    e.allDay          = allDay;
    e.notes           = notes;
    e.location        = location;
    e.reminderMinutes = reminderMinutes;
    if (m_repo->insert(e) > 0) reload();
}

void EventListModel::updateEvent(int id, const QString& title, const QDateTime& start,
                                 const QDateTime& end, const QString& category,
                                 const QString& rrule, bool allDay,
                                 const QString& notes, const QString& location,
                                 int reminderMinutes) {
    Event e;
    e.id              = id;
    e.title           = title;
    e.start           = start;
    e.end             = end;
    e.category        = category;
    e.rrule           = rrule;
    e.allDay          = allDay;
    e.notes           = notes;
    e.location        = location;
    e.reminderMinutes = reminderMinutes;
    if (m_repo->update(e)) reload();
}

void EventListModel::moveEvent(int id, const QDateTime& newStart) {
    for (const Event& cur : m_events) {
        if (cur.id == id) {
            Event next = cur;
            const qint64 dur = cur.start.secsTo(cur.end);
            next.start = newStart;
            next.end   = newStart.addSecs(dur);
            if (m_repo->update(next)) reload();
            return;
        }
    }
}

void EventListModel::resizeEvent(int id, const QDateTime& newEnd) {
    for (const Event& cur : m_events) {
        if (cur.id == id) {
            Event next = cur;
            if (newEnd > cur.start) {
                next.end = newEnd;
                if (m_repo->update(next)) reload();
            }
            return;
        }
    }
}

void EventListModel::removeEvent(int id) {
    if (m_repo->remove(id)) reload();
}

QVariantList EventListModel::search(const QString& q) {
    QVariantList out;
    for (const Event& e : m_repo->search(q, 25)) {
        QVariantMap m;
        m["id"]              = e.id;
        m["title"]           = e.title;
        m["start"]           = e.start;
        m["end"]             = e.end;
        m["category"]        = e.category;
        m["source"]          = e.source;
        m["rrule"]           = e.rrule;
        m["allDay"]          = e.allDay;
        m["notes"]           = e.notes;
        m["location"]        = e.location;
        m["reminderMinutes"] = e.reminderMinutes;
        out.append(m);
    }
    return out;
}

void EventListModel::startPolling(int intervalMs) {
    if (!m_pollTimer) {
        m_pollTimer = new QTimer(this);
        connect(m_pollTimer, &QTimer::timeout, this, &EventListModel::reload);
    }
    m_pollTimer->start(intervalMs);
}

void EventListModel::stopPolling() {
    if (m_pollTimer) m_pollTimer->stop();
}

} // namespace dias
