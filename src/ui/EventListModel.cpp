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

    QVector<Event> fresh = m_repo->inRange(m_viewStart, m_viewStart.addDays(m_viewDays));

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
                                 const QDateTime& end, const QString& category) {
    Event e;
    e.title = title;
    e.start = start;
    e.end = end;
    e.category = category;
    if (m_repo->insert(e) > 0) reload();
}

void EventListModel::updateEvent(int id, const QString& title, const QDateTime& start,
                                 const QDateTime& end, const QString& category) {
    Event e;
    e.id = id;
    e.title = title;
    e.start = start;
    e.end = end;
    e.category = category;
    if (m_repo->update(e)) reload();
}

void EventListModel::removeEvent(int id) {
    if (m_repo->remove(id)) reload();
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
