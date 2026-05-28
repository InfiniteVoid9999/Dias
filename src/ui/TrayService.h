#pragma once

#include <QObject>

QT_FORWARD_DECLARE_CLASS(QSystemTrayIcon)
QT_FORWARD_DECLARE_CLASS(QMenu)

namespace dias {

// System tray icon + menu. QML connects to the signals.
class TrayService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)

public:
    explicit TrayService(QObject* parent = nullptr);
    ~TrayService() override;

    bool available() const;

    Q_INVOKABLE void showMessage(const QString& title, const QString& body);

signals:
    void showRequested();
    void hideRequested();
    void quickAddRequested();
    void quitRequested();

private:
    QSystemTrayIcon* m_tray = nullptr;
    QMenu*           m_menu = nullptr;
};

} // namespace dias
