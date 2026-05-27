import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: root
    width: 1400
    height: 900
    visible: true
    title: "Dias"
    flags: Qt.Window | Qt.FramelessWindowHint

    // user-overridable theme: 0 = follow system, 1 = light, 2 = dark
    property int userTheme: 0
    Material.theme: userTheme === 1 ? Material.Light
                    : userTheme === 2 ? Material.Dark
                    : Material.System
    Material.accent: "#cba6f7"
    color: Material.theme === Material.Dark ? "#11111b" : "#eff1f5"

    readonly property color subtleLine: Qt.alpha(Material.foreground, 0.08)
    readonly property color mutedFg: Qt.alpha(Material.foreground, 0.55)

    Overlay.modal: Rectangle {
        color: Qt.rgba(0, 0, 0, 0.55)
    }

    Shortcut {
        sequences: ["Escape"]
        enabled: !editDialog.visible && !taskDialog.visible && !statusPopup.visible
        onActivated: Qt.quit()
    }
    Shortcut {
        sequences: ["Right", "L"]
        enabled: !editDialog.visible && !taskDialog.visible
        onActivated: weekView.next()
    }
    Shortcut {
        sequences: ["Left", "H"]
        enabled: !editDialog.visible && !taskDialog.visible
        onActivated: weekView.prev()
    }
    Shortcut {
        sequences: ["T"]
        enabled: !editDialog.visible && !taskDialog.visible
        onActivated: weekView.gotoToday()
    }
    Shortcut {
        sequences: ["D"]
        enabled: !editDialog.visible && !taskDialog.visible
        onActivated: setDayView()
    }
    Shortcut {
        sequences: ["W"]
        enabled: !editDialog.visible && !taskDialog.visible
        onActivated: setWeekView()
    }

    function _localMidnight(d) { var x = new Date(d); x.setHours(0,0,0,0); return x; }
    function _mondayOf(d) {
        var x = _localMidnight(d);
        var dow = (x.getDay() + 6) % 7;
        x.setDate(x.getDate() - dow);
        return x;
    }

    function setDayView() {
        var anchor = EventModel.viewDays === 7 ? _localMidnight(new Date()) : EventModel.viewStart;
        EventModel.viewStart = anchor;
        EventModel.viewDays = 1;
    }
    function setWeekView() {
        var anchor = _mondayOf(EventModel.viewDays === 1 ? EventModel.viewStart : new Date());
        EventModel.viewStart = anchor;
        EventModel.viewDays = 7;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: header
            Layout.fillWidth: true
            Layout.preferredHeight: 80

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(weekView.viewStart, "MMMM yyyy")
                font.pixelSize: 30
                font.weight: Font.Bold
                color: Material.foreground
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    var s = weekView.viewStart;
                    if (weekView.dayCount === 1) {
                        return Qt.formatDate(s, "ddd d MMM");
                    }
                    var e = new Date(s); e.setDate(e.getDate() + weekView.dayCount - 1);
                    return Qt.formatDate(s, "d MMM") + " – " + Qt.formatDate(e, "d MMM");
                }
                font.pixelSize: 13
                opacity: 0.6
                color: Material.foreground
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                ToolButton {
                    text: "Day"
                    highlighted: weekView.dayCount === 1
                    onClicked: setDayView()
                }
                ToolButton {
                    text: "Week"
                    highlighted: weekView.dayCount === 7
                    onClicked: setWeekView()
                }
                Rectangle {
                    width: 1; height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.subtleLine
                }
                ToolButton { text: "‹"; font.pixelSize: 22; onClicked: weekView.prev() }
                ToolButton { text: "Today"; font.pixelSize: 13; onClicked: weekView.gotoToday() }
                ToolButton { text: "›"; font.pixelSize: 22; onClicked: weekView.next() }
                Rectangle {
                    width: 1; height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.subtleLine
                }
                ToolButton {
                    text: root.userTheme === 1 ? "Light"
                          : root.userTheme === 2 ? "Dark"
                          : "Auto"
                    onClicked: root.userTheme = (root.userTheme + 1) % 3
                }
                ToolButton {
                    text: "Export"
                    onClicked: {
                        var msg = Exporter.exportTo(Exporter.defaultDir());
                        statusPopup.show(msg === ""
                            ? "Exported to " + Exporter.defaultDir()
                            : "Export failed: " + msg);
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.subtleLine
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            WeekView {
                id: weekView
                Layout.fillHeight: true
                Layout.fillWidth: true

                onCreateAt: function(day, hour) {
                    var s = new Date(day);
                    s.setHours(hour, 0, 0, 0);
                    var e = new Date(s);
                    e.setHours(s.getHours() + 1);
                    editDialog.openFor(0, "", s, e, "");
                }
                onEditEvent: function(id, evTitle, start, end, category) {
                    editDialog.openFor(id, evTitle, start, end, category);
                }
                onEditTask: function(id, taskText, due, hasDue) {
                    taskDialog.openFor(id, taskText, due, hasDue);
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: root.subtleLine
            }

            TodoPanel {
                id: todoPanel
                Layout.preferredWidth: 340
                Layout.fillHeight: true

                onAddRequested: {
                    var now = new Date();
                    now.setMinutes(0, 0, 0);
                    now.setHours(now.getHours() + 1);
                    taskDialog.openFor(0, "", now, false);
                }
                onEditRequested: function(id, taskText, due, hasDue) {
                    taskDialog.openFor(id, taskText, due, hasDue);
                }
            }
        }
    }

    EventEditDialog {
        id: editDialog
        anchors.centerIn: parent

        onSaved: function(id, evTitle, start, end, category) {
            if (id <= 0) EventModel.createEvent(evTitle, start, end, category);
            else         EventModel.updateEvent(id, evTitle, start, end, category);
        }
        onRemoved: function(id) {
            EventModel.removeEvent(id);
        }
    }

    TaskEditDialog {
        id: taskDialog
        anchors.centerIn: parent

        onSaved: function(id, taskText, due, hasDue) {
            var d = hasDue ? due : new Date(NaN);
            if (id <= 0) TaskModel.createTask(taskText, d);
            else         TaskModel.updateTask(id, taskText, d);
        }
        onRemoved: function(id) {
            TaskModel.removeTask(id);
        }
    }

    Popup {
        id: statusPopup
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
        x: (root.width - width) / 2
        y: root.height - height - 32
        padding: 14

        property alias text: statusText.text

        background: Rectangle {
            radius: 10
            color: Material.theme === Material.Dark ? "#313244" : "#1e1e2e"
        }

        contentItem: Text {
            id: statusText
            color: "#cdd6f4"
            font.pixelSize: 13
        }

        function show(msg) {
            text = msg;
            open();
            hideTimer.restart();
        }

        Timer {
            id: hideTimer
            interval: 2500
            onTriggered: statusPopup.close()
        }
    }
}
