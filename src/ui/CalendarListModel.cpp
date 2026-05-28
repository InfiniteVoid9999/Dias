#include "CalendarListModel.h"

namespace dias {

CalendarListModel::CalendarListModel(CalendarRepository* repo, QObject* parent)
    : QAbstractListModel(parent), m_repo(repo) {
    reload();
}

int CalendarListModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return static_cast<int>(m_calendars.size());
}

QVariant CalendarListModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() >= m_calendars.size()) return {};
    const Calendar& c = m_calendars[index.row()];
    switch (role) {
        case IdRole:      return c.id;
        case NameRole:    return c.name;
        case ColorRole:   return c.color;
        case VisibleRole: return c.visible;
    }
    return {};
}

QHash<int, QByteArray> CalendarListModel::roleNames() const {
    return {
        {IdRole,      "id"},
        {NameRole,    "name"},
        {ColorRole,   "color"},
        // Renamed from "visible" so QML delegate can use required-property
        // without colliding with Item's built-in `visible`.
        {VisibleRole, "shown"},
    };
}

void CalendarListModel::reload() {
    beginResetModel();
    m_calendars = m_repo->all();
    endResetModel();
}

void CalendarListModel::createCalendar(const QString& name, const QString& color) {
    Calendar c;
    c.name = name.isEmpty() ? "New calendar" : name;
    c.color = color.isEmpty() ? "#89b4fa" : color;
    if (m_repo->insert(c) > 0) reload();
}

void CalendarListModel::updateCalendar(int id, const QString& name, const QString& color) {
    for (Calendar c : m_calendars) {
        if (c.id == id) {
            c.name = name;
            c.color = color;
            if (m_repo->update(c)) reload();
            return;
        }
    }
}

void CalendarListModel::removeCalendar(int id) {
    if (m_repo->remove(id)) reload();
}

void CalendarListModel::setVisible(int id, bool visible) {
    if (m_repo->setVisible(id, visible)) {
        for (Calendar& c : m_calendars) if (c.id == id) c.visible = visible;
        const int n = m_calendars.size();
        for (int i = 0; i < n; ++i) {
            if (m_calendars[i].id == id) {
                emit dataChanged(index(i, 0), index(i, 0), {VisibleRole});
                break;
            }
        }
        emit visibilityChanged();
    }
}

QString CalendarListModel::colorOf(int id) const {
    for (const Calendar& c : m_calendars) if (c.id == id) return c.color;
    return {};
}

QString CalendarListModel::nameOf(int id) const {
    for (const Calendar& c : m_calendars) if (c.id == id) return c.name;
    return {};
}

QVector<int> CalendarListModel::visibleIdList() const {
    QVector<int> out;
    for (const Calendar& c : m_calendars) if (c.visible) out.append(c.id);
    return out;
}

} // namespace dias
