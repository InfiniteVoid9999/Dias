#pragma once

#include "core/Calendar.h"
#include "core/CalendarRepository.h"

#include <QAbstractListModel>
#include <QHash>
#include <QVector>

namespace dias {

class CalendarListModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        ColorRole,
        VisibleRole,
    };

    explicit CalendarListModel(CalendarRepository* repo, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void reload();
    Q_INVOKABLE void createCalendar(const QString& name, const QString& color);
    Q_INVOKABLE void updateCalendar(int id, const QString& name, const QString& color);
    Q_INVOKABLE void removeCalendar(int id);
    Q_INVOKABLE void setVisible(int id, bool visible);

    // Lookup helpers for other models.
    Q_INVOKABLE QString colorOf(int id) const;
    Q_INVOKABLE QString nameOf(int id) const;
    QVector<int>        visibleIdList() const;

signals:
    void visibilityChanged();

private:
    CalendarRepository* m_repo;
    QVector<Calendar>   m_calendars;
};

} // namespace dias
