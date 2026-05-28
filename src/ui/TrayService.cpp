#include "TrayService.h"

#include <QAction>
#include <QIcon>
#include <QMenu>
#include <QSystemTrayIcon>

namespace dias {

TrayService::TrayService(QObject* parent) : QObject(parent) {
    if (!QSystemTrayIcon::isSystemTrayAvailable()) return;

    m_menu = new QMenu();
    auto* showAct = m_menu->addAction("Show Dias");
    auto* hideAct = m_menu->addAction("Hide");
    m_menu->addSeparator();
    auto* qaAct   = m_menu->addAction("Quick add…");
    m_menu->addSeparator();
    auto* quitAct = m_menu->addAction("Quit");

    connect(showAct, &QAction::triggered, this, &TrayService::showRequested);
    connect(hideAct, &QAction::triggered, this, &TrayService::hideRequested);
    connect(qaAct,   &QAction::triggered, this, &TrayService::quickAddRequested);
    connect(quitAct, &QAction::triggered, this, &TrayService::quitRequested);

    m_tray = new QSystemTrayIcon(this);
    m_tray->setIcon(QIcon::fromTheme("appointment-soon",
                    QIcon::fromTheme("calendar",
                    QIcon::fromTheme("x-office-calendar"))));
    m_tray->setToolTip("Dias");
    m_tray->setContextMenu(m_menu);
    connect(m_tray, &QSystemTrayIcon::activated,
        [this](QSystemTrayIcon::ActivationReason r) {
            if (r == QSystemTrayIcon::Trigger) emit showRequested();
        });
    m_tray->show();
}

TrayService::~TrayService() {
    delete m_menu;
}

bool TrayService::available() const { return m_tray != nullptr; }

void TrayService::showMessage(const QString& title, const QString& body) {
    if (m_tray) m_tray->showMessage(title, body, QSystemTrayIcon::Information, 4000);
}

} // namespace dias
