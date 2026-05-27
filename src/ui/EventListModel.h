#pragma once

#include "core/Event.h"
#include "core/EventRepository.h"

#include <QAbstractListModel>
#include <QDateTime>
#include <QVector>

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
    };

    explicit EventListModel(EventRepository* repo, QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QDateTime viewStart() const { return m_viewStart; }
    void setViewStart(const QDateTime& d);

    int viewDays() const { return m_viewDays; }
    void setViewDays(int n);

    Q_INVOKABLE void createEvent(const QString& title, const QDateTime& start,
                                 const QDateTime& end, const QString& category);
    Q_INVOKABLE void updateEvent(int id, const QString& title, const QDateTime& start,
                                 const QDateTime& end, const QString& category);
    Q_INVOKABLE void removeEvent(int id);

signals:
    void viewStartChanged();
    void viewDaysChanged();

private:
    void reload();

    EventRepository* m_repo;
    QDateTime m_viewStart;
    int m_viewDays = 7;
    QVector<Event> m_events;
};

} // namespace dias
