#include "McpServer.h"
#include "core/Database.h"
#include "core/EventRepository.h"
#include "core/TaskRepository.h"

#include <QCoreApplication>
#include <QFile>
#include <QString>

#include <cstdio>

#if defined(__has_feature)
#  if __has_feature(address_sanitizer)
#    define DIAS_ASAN_BUILD 1
#  endif
#endif
#if !defined(DIAS_ASAN_BUILD) && defined(__SANITIZE_ADDRESS__)
#  define DIAS_ASAN_BUILD 1
#endif

#ifdef DIAS_ASAN_BUILD
extern "C" const char* __asan_default_options() { return "detect_leaks=0"; }
#endif

// dias-mcp: stdio MCP server. One JSON-RPC message per line on stdin/stdout.
// stderr is for human-readable diagnostics so it doesn't corrupt the protocol.
int main(int argc, char* argv[]) {
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName("Dias");
    QCoreApplication::setOrganizationName("Dias");

    dias::Database db(dias::Database::defaultPath());
    if (!db.open()) {
        std::fprintf(stderr, "dias-mcp: failed to open db at %s\n",
                     dias::Database::defaultPath().toUtf8().constData());
        return 1;
    }

    dias::EventRepository events(db.handle());
    dias::TaskRepository  tasks(db.handle());

    dias::McpServer server(&events, &tasks);

    std::fprintf(stderr, "dias-mcp: ready (protocol 2024-11-05, db=%s)\n",
                 dias::Database::defaultPath().toUtf8().constData());

    // Line-delimited JSON-RPC from stdin. fgets() so partial reads don't desync.
    constexpr size_t kMaxLine = 65536;
    QByteArray buf(kMaxLine, Qt::Uninitialized);
    while (true) {
        if (!std::fgets(buf.data(), kMaxLine, stdin)) break;  // EOF
        QByteArray line(buf.constData());
        if (!server.handleOneLine(line)) break;
    }

    std::fprintf(stderr, "dias-mcp: exiting\n");
    return 0;
}
