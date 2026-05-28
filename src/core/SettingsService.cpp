#include "SettingsService.h"

namespace dias {

SettingsService::SettingsService(QObject* parent)
    : QObject(parent), m_s(QSettings::IniFormat, QSettings::UserScope, "Dias", "Dias") {}

QVariant SettingsService::get(const QString& key, const QVariant& fallback) const {
    return m_s.value(key, fallback);
}

void SettingsService::set(const QString& key, const QVariant& value) {
    m_s.setValue(key, value);
}

void SettingsService::sync() {
    m_s.sync();
}

} // namespace dias
