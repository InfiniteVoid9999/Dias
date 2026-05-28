import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import Dias

ApplicationWindow {
    id: root
    width: 1400
    height: 900
    visible: true
    title: "Dias"
    flags: Qt.Window | Qt.FramelessWindowHint

    // 0 = follow system, 1 = light, 2 = dark
    property int userTheme: 0
    readonly property bool _isDark: {
        if (userTheme === 2) return true;
        if (userTheme === 1) return false;
        return Qt.application.styleHints.colorScheme === Qt.Dark;
    }
    on_IsDarkChanged: Theme.dark = _isDark
    Component.onCompleted: Theme.dark = _isDark

    Material.theme: _isDark ? Material.Dark : Material.Light
    Material.accent: Theme.accent
    Material.foreground: Theme.fg
    Material.background: Theme.bg

    color: Theme.bg

    font.family: Theme.sansStack[0]

    Overlay.modal: Rectangle { color: Theme.scrim }

    // -------- shortcuts (gated when modals open) --------
    Shortcut {
        sequences: ["Escape"]
        enabled: !editDialog.visible && !taskDialog.visible && !statusPopup.visible
        onActivated: Qt.quit()
    }
    Shortcut { sequences: ["Right", "L"]; enabled: !editDialog.visible && !taskDialog.visible; onActivated: weekView.next() }
    Shortcut { sequences: ["Left",  "H"]; enabled: !editDialog.visible && !taskDialog.visible; onActivated: weekView.prev() }
    Shortcut { sequences: ["T"];          enabled: !editDialog.visible && !taskDialog.visible; onActivated: weekView.gotoToday() }
    Shortcut { sequences: ["D"];          enabled: !editDialog.visible && !taskDialog.visible; onActivated: setDayView() }
    Shortcut { sequences: ["W"];          enabled: !editDialog.visible && !taskDialog.visible; onActivated: setWeekView() }
    Shortcut { sequences: ["Ctrl+E"];     enabled: !editDialog.visible && !taskDialog.visible; onActivated: doExport() }

    // -------- view helpers --------
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
    function doExport() {
        var msg = Exporter.exportTo(Exporter.defaultDir());
        statusPopup.show(msg === ""
            ? "Exported to " + Exporter.defaultDir()
            : "Export failed: " + msg);
    }
    function doObsidianSync() {
        var r = Obsidian.ingest(Obsidian.defaultVaultPath());
        if (r.ok) {
            statusPopup.show("Obsidian: " + r.imported + " imported, "
                             + r.updated + " updated, " + r.skipped + " skipped");
            EventModel.reload();
        } else {
            statusPopup.show("Obsidian sync failed: " + r.error);
        }
    }

    // -------- helper: icon button (Material Symbols, ligature-based) --------
    component IconBtn: ToolButton {
        property string glyph: ""
        property bool emphasized: false
        text: glyph
        font.family: Theme.iconFont
        font.pixelSize: 22
        Material.foreground: emphasized ? Theme.accent : Theme.fg
        ToolTip.visible: hovered && ToolTip.text !== ""
        ToolTip.delay: 600
    }

    // -------- layout --------
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // header strip
        Item {
            id: header
            Layout.fillWidth: true
            Layout.preferredHeight: 84

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.sp6
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp1

                Text {
                    text: Qt.formatDate(weekView.viewStart, "MMMM yyyy")
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textDisplay
                    font.weight: Theme.weightBold
                    color: Theme.fg
                }
                Text {
                    text: {
                        var s = weekView.viewStart;
                        if (weekView.dayCount === 1) return Qt.formatDate(s, "dddd, d MMM");
                        var e = new Date(s); e.setDate(e.getDate() + weekView.dayCount - 1);
                        return Qt.formatDate(s, "d MMM") + " – " + Qt.formatDate(e, "d MMM");
                    }
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textCaption + 1
                    color: Theme.fgMuted
                }
            }

            // right cluster: view toggle | nav | theme + export
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.sp5
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp1

                // segmented view toggle
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 36
                    width: 124
                    radius: Theme.radiusPill
                    color: Theme.surface

                    Row {
                        anchors.fill: parent
                        anchors.margins: 3

                        Rectangle {
                            id: segHighlight
                            width: parent.width / 2
                            height: parent.height
                            radius: Theme.radiusPill
                            color: Theme.accent
                            x: weekView.dayCount === 1 ? 0 : parent.width / 2
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 3

                        Item {
                            width: parent.width / 2
                            height: parent.height
                            Text {
                                anchors.centerIn: parent
                                text: "Day"
                                font.family: Theme.sansStack[0]
                                font.pixelSize: Theme.textBody
                                font.weight: Theme.weightMedium
                                color: weekView.dayCount === 1 ? Theme.onAccent : Theme.fgMuted
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: setDayView()
                            }
                        }
                        Item {
                            width: parent.width / 2
                            height: parent.height
                            Text {
                                anchors.centerIn: parent
                                text: "Week"
                                font.family: Theme.sansStack[0]
                                font.pixelSize: Theme.textBody
                                font.weight: Theme.weightMedium
                                color: weekView.dayCount === 7 ? Theme.onAccent : Theme.fgMuted
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: setWeekView()
                            }
                        }
                    }
                }

                Item { width: Theme.sp3; height: 1 }

                // nav cluster
                IconBtn {
                    glyph: "chevron_left"
                    ToolTip.text: "Previous (H / ←)"
                    onClicked: weekView.prev()
                }
                ToolButton {
                    text: "Today"
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textBody
                    font.weight: Theme.weightMedium
                    Material.foreground: Theme.fg
                    ToolTip.visible: hovered
                    ToolTip.delay: 600
                    ToolTip.text: "Today (T)"
                    onClicked: weekView.gotoToday()
                }
                IconBtn {
                    glyph: "chevron_right"
                    ToolTip.text: "Next (L / →)"
                    onClicked: weekView.next()
                }

                Item { width: Theme.sp3; height: 1 }

                IconBtn {
                    glyph: root.userTheme === 1 ? "light_mode"
                          : root.userTheme === 2 ? "dark_mode"
                          : "brightness_auto"
                    ToolTip.text: root.userTheme === 1 ? "Light (click for Dark)"
                                  : root.userTheme === 2 ? "Dark (click for Auto)"
                                  : "Auto — follows system (click for Light)"
                    onClicked: root.userTheme = (root.userTheme + 1) % 3
                }
                IconBtn {
                    glyph: "hub"
                    ToolTip.text: "Sync from Obsidian vault"
                    onClicked: doObsidianSync()
                }
                IconBtn {
                    glyph: "file_download"
                    ToolTip.text: "Export (Ctrl+E)"
                    onClicked: doExport()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.divider
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
                    editDialog.openFor(0, "", s, e, "", "");
                }
                onEditEvent: function(id, evTitle, start, end, category, rrule) {
                    editDialog.openFor(id, evTitle, start, end, category, rrule);
                }
                onEditTask: function(id, taskText, due, hasDue) {
                    taskDialog.openFor(id, taskText, due, hasDue);
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Theme.divider
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

        onSaved: function(id, evTitle, start, end, category, rrule) {
            if (id <= 0) EventModel.createEvent(evTitle, start, end, category, rrule);
            else         EventModel.updateEvent(id, evTitle, start, end, category, rrule);
        }
        onRemoved: function(id) { EventModel.removeEvent(id); }
    }

    TaskEditDialog {
        id: taskDialog
        anchors.centerIn: parent

        onSaved: function(id, taskText, due, hasDue) {
            var d = hasDue ? due : new Date(NaN);
            if (id <= 0) TaskModel.createTask(taskText, d);
            else         TaskModel.updateTask(id, taskText, d);
        }
        onRemoved: function(id) { TaskModel.removeTask(id); }
    }

    Popup {
        id: statusPopup
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
        x: (root.width - width) / 2
        y: root.height - height - Theme.sp6
        padding: Theme.sp3

        property alias text: statusText.text

        background: Rectangle {
            radius: Theme.radiusCard
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
        }
        contentItem: Text {
            id: statusText
            color: Theme.fg
            font.family: Theme.sansStack[0]
            font.pixelSize: Theme.textBody
        }
        function show(msg) { text = msg; open(); hideTimer.restart(); }

        Timer { id: hideTimer; interval: 2500; onTriggered: statusPopup.close() }
    }
}
