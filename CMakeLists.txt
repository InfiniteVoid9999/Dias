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

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Sql)

qt_standard_project_setup(REQUIRES 6.6)
qt_policy(SET QTP0004 NEW)

qt_add_executable(dias
    src/main.cpp
    src/core/Database.cpp
    src/core/Database.h
    src/core/Event.h
    src/core/EventRepository.cpp
    src/core/EventRepository.h
    src/core/ExportService.cpp
    src/core/ExportService.h
    src/core/Task.h
    src/core/TaskRepository.cpp
    src/core/TaskRepository.h
    src/ui/EventListModel.cpp
    src/ui/EventListModel.h
    src/ui/TaskListModel.cpp
    src/ui/TaskListModel.h
)

qt_add_qml_module(dias
    URI Dias
    VERSION 1.0
    QML_FILES
        src/qml/Main.qml
        src/qml/WeekView.qml
        src/qml/EventEditDialog.qml
        src/qml/TaskEditDialog.qml
        src/qml/TodoPanel.qml
)

target_include_directories(dias PRIVATE src)

target_link_libraries(dias PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(dias PRIVATE -Wall -Wextra -Wpedantic -fsanitize=address,undefined)
    target_link_options(dias PRIVATE -fsanitize=address,undefined)
endif()
