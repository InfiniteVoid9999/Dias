cmake_minimum_required(VERSION 3.21)
project(dias LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug)
endif()

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Sql DBus)

qt_standard_project_setup(REQUIRES 6.6)
qt_policy(SET QTP0004 NEW)

# -----------------------------------------------------------------------------
# dias-core: pure C++/Qt-Core/Qt-Sql library shared by the UI and MCP binaries.
# Anything below src/core/ goes here. No QGui, no QQuick, no QML — this keeps
# the agent spine (MCP server) headless and link-clean.
# -----------------------------------------------------------------------------
add_library(dias-core STATIC
    src/core/Database.cpp
    src/core/Database.h
    src/core/Event.h
    src/core/EventRepository.cpp
    src/core/EventRepository.h
    src/core/ExportService.cpp
    src/core/ExportService.h
    src/core/GCalSync.cpp
    src/core/GCalSync.h
    src/core/ObsidianIngest.cpp
    src/core/ObsidianIngest.h
    src/core/ReminderService.cpp
    src/core/ReminderService.h
    src/core/RRule.cpp
    src/core/RRule.h
    src/core/Task.h
    src/core/TaskRepository.cpp
    src/core/TaskRepository.h
)
target_include_directories(dias-core PUBLIC src)
target_link_libraries(dias-core PUBLIC Qt6::Core Qt6::Sql Qt6::DBus)

# -----------------------------------------------------------------------------
# dias: the Qt Quick UI binary.
# -----------------------------------------------------------------------------
qt_add_executable(dias
    src/main.cpp
    src/ui/EventListModel.cpp
    src/ui/EventListModel.h
    src/ui/TaskListModel.cpp
    src/ui/TaskListModel.h
)

set_source_files_properties(src/qml/Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(dias
    URI Dias
    VERSION 1.0
    QML_FILES
        src/qml/Main.qml
        src/qml/Theme.qml
        src/qml/WeekView.qml
        src/qml/MonthView.qml
        src/qml/YearView.qml
        src/qml/EventEditDialog.qml
        src/qml/TaskEditDialog.qml
        src/qml/TodoPanel.qml
        src/qml/RecurrenceEditor.qml
        src/qml/QuickAddPopup.qml
)

target_link_libraries(dias PRIVATE
    dias-core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

# -----------------------------------------------------------------------------
# dias-mcp: the MCP (Model Context Protocol) server binary.
# Headless. Speaks JSON-RPC 2.0 over stdio. Wraps dias-core repositories so any
# MCP client (Claude desktop, Cowork, Ollama via a shim) can read/write the
# user's calendar as a first-class agent. See src/mcp/.
# -----------------------------------------------------------------------------
qt_add_executable(dias-mcp
    src/mcp/main.cpp
    src/mcp/McpServer.cpp
    src/mcp/McpServer.h
)
target_link_libraries(dias-mcp PRIVATE dias-core)

# -----------------------------------------------------------------------------
# Debug build hardening: ASAN/UBSAN on for runtime bug detection.
# -----------------------------------------------------------------------------
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(dias-core PUBLIC -Wall -Wextra -Wpedantic -fsanitize=address,undefined)
    target_link_options(dias-core PUBLIC -fsanitize=address,undefined)
endif()
