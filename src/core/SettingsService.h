#pragma once

#include <QObject>
#include <QSettings>
#include <QString>
#include <QVariant>

namespace dias {

// Thin Q_INVOKABLE wrapper around QSettings so QML can persist view
// preferences. Storage location is the default per Qt/QSettings on Linux
// (~/.config/Dias/Dias.conf).
class SettingsService : public QObject {
    Q_OBJECT

public:
    explicit SettingsService(QObject* parent = nullptr);

    Q_INVOKABLE QVariant get(const QString& key, const QVariant& fallback = {}) const;
    Q_INVOKABLE void set(const QString& key, const QVariant& value);
    Q_INVOKABLE void sync();

private:
    QSettings m_s;
};

} // namespace dias
