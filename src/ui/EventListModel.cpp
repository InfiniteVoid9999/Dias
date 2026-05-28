#include "EventListModel.h"
#include "CalendarListModel.h"
#include "UndoService.h"

#include <QTimer>

#include <algorithm>
#include <memory>

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
        case LaneRole:         return m_laneOf.value(e.id, 0);
        case LanesRole:        return m_lanesOf.value(e.id, 1);
        case CalendarIdRole:   return e.calendarId;
        case CalendarColorRole:
            return m_calendars ? m_calendars->colorOf(e.calendarId) : QString();
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
        {LaneRole,         "lane"},
        {LanesRole,        "lanes"},
        {CalendarIdRole,   "calendarId"},
        {CalendarColorRole,"calendarColor"},
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

    // Apply calendar visibility filter if one is set.
    if (m_visibilityFilterSet) {
        QVector<Event> kept;
        kept.reserve(fresh.size());
        for (const Event& e : fresh) {
            if (m_visibleCalendarIds.contains(e.calendarId)) kept.push_back(e);
        }
        fresh = std::move(kept);
    }

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

    // Skip work + view reset if nothing actually changed.
    // Diff key: (id, start, end, updated_at) per event. Cheap to compute.
    auto buildKey = [](const QVector<Event>& evs) {
        QString k;
        k.reserve(evs.size() * 24);
        for (const Event& e : evs) {
            k += QString::number(e.id) + ':'
               + QString::number(e.start.toSecsSinceEpoch()) + ':'
               + QString::number(e.end.toSecsSinceEpoch()) + ':'
               + QString::number(e.updatedAt) + '|';
        }
        return k;
    };
    const QString freshKey = buildKey(fresh);
    const bool dataChanged = (freshKey != m_lastDataKey);
    const bool recentChanged = !newRecent.isEmpty() || !m_recentAgentIds.isEmpty();

    if (!dataChanged && !recentChanged) {
        // Nothing to do — preserves scroll position and avoids redraw.
        m_lastReloadSec = QDateTime::currentSecsSinceEpoch();
        return;
    }

    // ---- compute overlap lanes (greedy lane-pack, grouped by start day) ----
    QHash<int, int> laneOf, lanesOf;
    {
        QHash<QDate, QVector<int>> byDay;
        for (int i = 0; i < fresh.size(); ++i) {
            if (fresh[i].allDay) continue;
            byDay[fresh[i].start.date()].append(i);
        }
        for (auto it = byDay.begin(); it != byDay.end(); ++it) {
            auto& idx = it.value();
            std::sort(idx.begin(), idx.end(), [&](int a, int b) {
                if (fresh[a].start != fresh[b].start) return fresh[a].start < fresh[b].start;
                return fresh[a].id < fresh[b].id;
            });
            QVector<QDateTime> laneEnds;
            for (int i : idx) {
                const Event& e = fresh[i];
                int chosen = -1;
                for (int l = 0; l < laneEnds.size(); ++l) {
                    if (laneEnds[l] <= e.start) { chosen = l; break; }
                }
                if (chosen < 0) {
                    chosen = laneEnds.size();
                    laneEnds.append(e.end);
                } else {
                    laneEnds[chosen] = e.end;
                }
                laneOf.insert(e.id, chosen);
            }
            for (int i : idx) {
                const Event& e = fresh[i];
                int maxLane = laneOf.value(e.id);
                for (int j : idx) {
                    if (j == i) continue;
                    const Event& other = fresh[j];
                    if (other.end <= e.start || other.start >= e.end) continue;
                    maxLane = std::max(maxLane, laneOf.value(other.id));
                }
                lanesOf.insert(e.id, maxLane + 1);
            }
        }
    }

    beginResetModel();
    m_events = std::move(fresh);
    m_recentAgentIds = std::move(newRecent);
    m_laneOf  = std::move(laneOf);
    m_lanesOf = std::move(lanesOf);
    m_lastDataKey = freshKey;
    endResetModel();

    m_lastReloadSec = QDateTime::currentSecsSinceEpoch();
    if (sawAgentEdit) emit agentEditDetected();
}

void EventListModel::createEvent(const QString& title, const QDateTime& start,
                                 const QDateTime& end, const QString& category,
                                 const QString& rrule, bool allDay,
                                 const QString& notes, const QString& location,
                                 int reminderMinutes, int calendarId) {
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
    e.calendarId      = calendarId > 0 ? calendarId : 1;
    if (m_repo->insert(e) > 0) reload();
}

void EventListModel::updateEvent(int id, const QString& title, const QDateTime& start,
                                 const QDateTime& end, const QString& category,
                                 const QString& rrule, bool allDay,
                                 const QString& notes, const QString& location,
                                 int reminderMinutes, int calendarId) {
    Event prev;
    bool found = false;
    for (const Event& cur : m_events) {
        if (cur.id == id) { prev = cur; found = true; break; }
    }
    Event e = prev;  // preserves source/createdBy/updatedAt fields
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
    e.calendarId      = calendarId > 0 ? calendarId : 1;
    if (m_repo->update(e)) {
        if (found && m_undoService) {
            auto repo = m_repo;
            auto self = this;
            m_undoService->push("Edit \"" + prev.title + "\"",
                [repo, self, prev]() { repo->update(prev); self->reload(); },
                [repo, self, e]()    { repo->update(e);    self->reload(); });
        }
        reload();
    }
}

void EventListModel::setVisibleCalendarIds(const QVariantList& ids) {
    QSet<int> s;
    for (const QVariant& v : ids) s.insert(v.toInt());
    if (s == m_visibleCalendarIds && m_visibilityFilterSet) return;
    m_visibleCalendarIds = s;
    m_visibilityFilterSet = true;
    m_lastDataKey.clear();  // force reload
    reload();
}

void EventListModel::moveEvent(int id, const QDateTime& newStart) {
    for (const Event& cur : m_events) {
        if (cur.id == id) {
            Event prev = cur;
            Event next = cur;
            const qint64 dur = cur.start.secsTo(cur.end);
            next.start = newStart;
            next.end   = newStart.addSecs(dur);
            if (m_repo->update(next)) {
                if (m_undoService) {
                    auto repo = m_repo;
                    auto self = this;
                    m_undoService->push("Move \"" + cur.title + "\"",
                        [repo, self, prev]() { repo->update(prev); self->reload(); },
                        [repo, self, next]() { repo->update(next); self->reload(); });
                }
                reload();
            }
            return;
        }
    }
}

void EventListModel::resizeEvent(int id, const QDateTime& newEnd) {
    for (const Event& cur : m_events) {
        if (cur.id == id) {
            if (newEnd <= cur.start) return;
            Event prev = cur;
            Event next = cur;
            next.end = newEnd;
            if (m_repo->update(next)) {
                if (m_undoService) {
                    auto repo = m_repo;
                    auto self = this;
                    m_undoService->push("Resize \"" + cur.title + "\"",
                        [repo, self, prev]() { repo->update(prev); self->reload(); },
                        [repo, self, next]() { repo->update(next); self->reload(); });
                }
                reload();
            }
            return;
        }
    }
}

void EventListModel::removeEvent(int id) {
    // Capture full state for undo-of-delete.
    Event captured;
    bool found = false;
    for (const Event& cur : m_events) {
        if (cur.id == id) { captured = cur; found = true; break; }
    }
    if (!m_repo->remove(id)) return;

    if (found && m_undoService) {
        // The re-inserted row gets a fresh autoincrement id; track it via
        // shared_ptr so redo can delete the right row across cycles.
        auto sharedId = std::make_shared<int>(id);
        auto repo = m_repo;
        auto self = this;
        m_undoService->push("Delete \"" + captured.title + "\"",
            // undo: re-insert with captured payload (fresh id)
            [repo, self, captured, sharedId]() mutable {
                Event re = captured;
                re.id = 0;
                int newId = repo->insert(re);
                if (newId > 0) *sharedId = newId;
                self->reload();
            },
            // redo: delete whatever id is current
            [repo, self, sharedId]() {
                repo->remove(*sharedId);
                self->reload();
            });
    }
    reload();
}

int EventListModel::allDayPositionOf(int eventId) const {
    int pos = 0;
    for (const Event& e : m_events) {
        if (!e.allDay) continue;
        if (e.id == eventId) return pos;
        ++pos;
    }
    return -1;
}

int EventListModel::visibleAllDayCount() const {
    int n = 0;
    for (const Event& e : m_events) if (e.allDay) ++n;
    return n;
}

QVariantMap EventListModel::overlapLane(int eventId) const {
    // Find the target event.
    const Event* target = nullptr;
    for (const Event& e : m_events) {
        if (e.id == eventId) { target = &e; break; }
    }
    QVariantMap out;
    out["lane"]  = 0;
    out["lanes"] = 1;
    if (!target || target->allDay) return out;

    // Build the cluster of events that transitively overlap this target,
    // staying within the same day (the calling block is per-day-segment, so
    // we compare against the day-bounds of the target's start day).
    const QDate day = target->start.date();
    const QDateTime dayStart(day, QTime(0, 0));
    const QDateTime dayEnd = dayStart.addDays(1);

    auto clamp = [&](const Event& e, QDateTime& s, QDateTime& en) {
        s  = std::max(e.start, dayStart);
        en = std::min(e.end,   dayEnd);
    };

    QVector<const Event*> sameDay;
    for (const Event& e : m_events) {
        if (e.allDay) continue;
        if (e.end <= dayStart || e.start >= dayEnd) continue;
        sameDay.append(&e);
    }
    // Stable sort by start then duration.
    std::sort(sameDay.begin(), sameDay.end(), [](const Event* a, const Event* b) {
        if (a->start != b->start) return a->start < b->start;
        return a->id < b->id;
    });

    // Greedy lane packing: walk in start order, place each in the first lane
    // whose previous event ends <= this event's start.
    QVector<QDateTime> laneEnds;
    QHash<int, int> laneOf;
    for (const Event* e : sameDay) {
        QDateTime s, en;
        clamp(*e, s, en);
        int chosen = -1;
        for (int i = 0; i < laneEnds.size(); ++i) {
            if (laneEnds[i] <= s) { chosen = i; break; }
        }
        if (chosen < 0) {
            chosen = laneEnds.size();
            laneEnds.append(en);
        } else {
            laneEnds[chosen] = en;
        }
        laneOf.insert(e->id, chosen);
    }

    // Cluster width = max lane index used by anything overlapping the target.
    QDateTime tS, tE;
    clamp(*target, tS, tE);
    int cluster = 1;
    for (const Event* e : sameDay) {
        QDateTime s, en;
        clamp(*e, s, en);
        if (en <= tS || s >= tE) continue;
        cluster = std::max(cluster, laneOf.value(e->id) + 1);
    }

    out["lane"]  = laneOf.value(target->id);
    out["lanes"] = cluster;
    return out;
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
