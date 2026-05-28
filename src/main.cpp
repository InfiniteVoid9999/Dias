#include "core/Database.h"
#include "core/EventRepository.h"
#include "core/ExportService.h"
#include "core/GCalSync.h"
#include "core/IcsSync.h"
#include "core/ObsidianIngest.h"
#include "core/ReminderService.h"
#include "core/SettingsService.h"
#include "core/TaskRepository.h"
#include "ui/EventListModel.h"
#include "ui/TaskListModel.h"

#include <QDateTime>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickStyle>
#include <QTimer>
#include <QUrl>

#include <cstdio>
#include <string>

#if defined(__has_feature)
#  if __has_feature(address_sanitizer)
#    define DIAS_ASAN_BUILD 1
#  endif
#endif
#if !defined(DIAS_ASAN_BUILD) && defined(__SANITIZE_ADDRESS__)
#  define DIAS_ASAN_BUILD 1
#endif

#ifdef DIAS_ASAN_BUILD
extern "C" const char* __asan_default_options() {
    return "detect_leaks=0";
}
#endif

static QDateTime mondayOfWeek(const QDateTime& now) {
    const QDate d = now.date();
    const int dow = d.dayOfWeek(); // Mon=1..Sun=7
    return QDateTime(d.addDays(1 - dow), QTime(0, 0));
}

int main(int argc, char* argv[]) {
    const std::string arg1 = argc > 1 ? argv[1] : "";
    const bool smoke    = arg1 == "--smoke";
    const bool qmlcheck = arg1 == "--qmlcheck";

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName("Dias");
    QGuiApplication::setOrganizationName("Dias");

    QQuickStyle::setStyle("Material");

    dias::Database db(dias::Database::defaultPath());
    if (!db.open()) return 1;

    dias::EventRepository eventRepo(db.handle());
    dias::TaskRepository  taskRepo(db.handle());

    dias::EventListModel eventModel(&eventRepo);
    eventModel.setViewDays(7);
    eventModel.setViewStart(mondayOfWeek(QDateTime::currentDateTime()));
    eventModel.startPolling(2000);  // pick up external writes (MCP, sync) ~live

    dias::TaskListModel taskModel(&taskRepo);
    taskModel.startPolling(2000);

    dias::ExportService exporter(&eventRepo, &taskRepo);
    dias::ObsidianIngest obsidian(&eventRepo, &taskRepo, db.handle());
    dias::GCalSync gcal(&eventRepo, db.handle());
    dias::IcsSync ics(&eventRepo, db.handle());
    dias::ReminderService reminders(&eventRepo);
    reminders.start(30000);  // poll every 30s
    dias::SettingsService settings;

    if (smoke) {
        std::fprintf(stderr, "[dias] smoke ok (%d events, %d tasks)\n",
                     eventModel.rowCount(), taskModel.rowCount());
        return 0;
    }

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
        [](const QList<QQmlError>& warnings) {
            for (const QQmlError& w : warnings) {
                std::fprintf(stderr, "[qml] %s\n", w.toString().toUtf8().constData());
            }
            std::fflush(stderr);
        });
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        [](const QUrl& url) {
            std::fprintf(stderr, "[qml] objectCreationFailed: %s\n", url.toString().toUtf8().constData());
            std::fflush(stderr);
        });
    engine.rootContext()->setContextProperty("EventModel", &eventModel);
    engine.rootContext()->setContextProperty("TaskModel",  &taskModel);
    engine.rootContext()->setContextProperty("Exporter",   &exporter);
    engine.rootContext()->setContextProperty("Obsidian",   &obsidian);
    engine.rootContext()->setContextProperty("GCal",       &gcal);
    engine.rootContext()->setContextProperty("Ics",        &ics);
    engine.rootContext()->setContextProperty("Settings",   &settings);
    engine.loadFromModule("Dias", "Main");
    if (engine.rootObjects().isEmpty()) {
        std::fprintf(stderr, "[dias] root objects empty -- QML load failed\n");
        std::fflush(stderr);
        return 1;
    }

    if (qmlcheck) {
        // Load QML, spin the loop for 1.5s to surface any deferred warnings,
        // then exit cleanly so ASAN/UBSAN flush properly.
        QTimer::singleShot(1500, &app, &QGuiApplication::quit);
    }

    return app.exec();
}
