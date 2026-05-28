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
    Shortcut { sequences: ["Right", "L"]; enabled: !editDialog.visible && !taskDialog.visible; onActivated: currentView().next() }
    Shortcut { sequences: ["Left",  "H"]; enabled: !editDialog.visible && !taskDialog.visible; onActivated: currentView().prev() }
    Shortcut { sequences: ["T"];          enabled: !editDialog.visible && !taskDialog.visible; onActivated: currentView().gotoToday() }
    Shortcut { sequences: ["D"];          enabled: !editDialog.visible && !taskDialog.visible; onActivated: setDayView() }
    Shortcut { sequences: ["W"];          enabled: !editDialog.visible && !taskDialog.visible; onActivated: setWeekView() }
    Shortcut { sequences: ["M"];          enabled: !editDialog.visible && !taskDialog.visible; onActivated: setMonthView() }
    Shortcut { sequences: ["Ctrl+E"];     enabled: !editDialog.visible && !taskDialog.visible; onActivated: doExport() }

    function currentView() {
        return viewLoader.item;
    }

    // -------- view helpers --------
    function _localMidnight(d) { var x = new Date(d); x.setHours(0,0,0,0); return x; }
    function _mondayOf(d) {
        var x = _localMidnight(d);
        var dow = (x.getDay() + 6) % 7;
        x.setDate(x.getDate() - dow);
        return x;
    }
    // viewMode tracks the current pane (week/day/month). It's derived from
    // EventModel.viewDays + a bool here because viewDays alone can't
    // distinguish "week of 7 days" from "first week of a 42-day month grid".
    property string viewMode: "week"

    function _firstMondayOfMonthGrid(anyDateInMonth) {
        var first = new Date(anyDateInMonth.getFullYear(), anyDateInMonth.getMonth(), 1);
        var dow = (first.getDay() + 6) % 7;
        var monday = new Date(first);
        monday.setDate(first.getDate() - dow);
        monday.setHours(0, 0, 0, 0);
        return monday;
    }

    function setDayView() {
        var anchor = viewMode === "week" ? _localMidnight(new Date())
                   : viewMode === "month" ? _localMidnight(new Date())
                   : EventModel.viewStart;
        viewMode = "day";
        EventModel.viewStart = anchor;
        EventModel.viewDays = 1;
    }
    function setWeekView() {
        var anchor = viewMode === "day" ? _mondayOf(EventModel.viewStart) : _mondayOf(new Date());
        viewMode = "week";
        EventModel.viewStart = anchor;
        EventModel.viewDays = 7;
    }
    function setMonthView() {
        var seed = (viewMode === "day" || viewMode === "week") ? EventModel.viewStart : new Date();
        viewMode = "month";
        EventModel.viewStart = _firstMondayOfMonthGrid(seed);
        EventModel.viewDays = 42;
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
    function doGCalSync() {
        var r = GCal.ingest();
        if (r.ok) {
            statusPopup.show("GCal: " + r.imported + " imported, "
                             + r.updated + " updated, " + r.skipped + " skipped");
            EventModel.reload();
        } else {
            statusPopup.show(r.error);
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
                    text: {
                        // For month view, derive month from a date safely inside the grid.
                        if (root.viewMode === "month") {
                            var d = new Date(EventModel.viewStart);
                            d.setDate(d.getDate() + 14);
                            return Qt.formatDate(d, "MMMM yyyy");
                        }
                        return Qt.formatDate(EventModel.viewStart, "MMMM yyyy");
                    }
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textDisplay
                    font.weight: Theme.weightBold
                    color: Theme.fg
                }
                Text {
                    text: {
                        var s = EventModel.viewStart;
                        if (root.viewMode === "day")  return Qt.formatDate(s, "dddd, d MMM");
                        if (root.viewMode === "month") return "";
                        var e = new Date(s); e.setDate(e.getDate() + 6);
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

                // segmented view toggle (3-way: Day / Week / Month)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 36
                    width: 180
                    radius: Theme.radiusPill
                    color: Theme.surface

                    property real segWidth: (width - 6) / 3

                    Rectangle {
                        id: segHighlight
                        width: parent.segWidth
                        height: parent.height - 6
                        y: 3
                        radius: Theme.radiusPill
                        color: Theme.accent
                        x: root.viewMode === "day"   ? 3
                          : root.viewMode === "week" ? 3 + parent.segWidth
                                                     : 3 + 2 * parent.segWidth
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 3

                        Repeater {
                            model: [
                                { mode: "day",   label: "Day"   },
                                { mode: "week",  label: "Week"  },
                                { mode: "month", label: "Month" }
                            ]
                            delegate: Item {
                                required property var modelData
                                width: parent.width / 3
                                height: parent.height
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.family: Theme.sansStack[0]
                                    font.pixelSize: Theme.textBody
                                    font.weight: Theme.weightMedium
                                    color: root.viewMode === modelData.mode ? Theme.onAccent : Theme.fgMuted
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.mode === "day")   setDayView();
                                        else if (modelData.mode === "week")  setWeekView();
                                        else if (modelData.mode === "month") setMonthView();
                                    }
                                }
                            }
                        }
                    }
                }

                Item { width: Theme.sp3; height: 1 }

                // nav cluster
                IconBtn {
                    glyph: "chevron_left"
                    ToolTip.text: "Previous (H / ←)"
                    onClicked: currentView().prev()
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
                    onClicked: currentView().gotoToday()
                }
                IconBtn {
                    glyph: "chevron_right"
                    ToolTip.text: "Next (L / →)"
                    onClicked: currentView().next()
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
                    glyph: "event_available"
                    ToolTip.text: GCal.isConfigured()
                                  ? "Sync from Google Calendar"
                                  : "Google Calendar (needs setup)"
                    emphasized: !GCal.isConfigured()
                    onClicked: doGCalSync()
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

            Loader {
                id: viewLoader
                Layout.fillHeight: true
                Layout.fillWidth: true
                sourceComponent: root.viewMode === "month" ? monthComp : weekComp
            }

            Component {
                id: weekComp
                WeekView {
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
                    onEditTask: function(id, taskText, due, hasDue, priority) {
                        taskDialog.openFor(id, taskText, due, hasDue, priority);
                    }
                }
            }

            Component {
                id: monthComp
                MonthView {
                    onEditEvent: function(id, evTitle, start, end, category, rrule) {
                        editDialog.openFor(id, evTitle, start, end, category, rrule);
                    }
                    onSelectDay: function(day) {
                        EventModel.viewStart = day;
                        EventModel.viewDays = 1;
                        root.viewMode = "day";
                    }
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
                    taskDialog.openFor(0, "", now, false, 0);
                }
                onEditRequested: function(id, taskText, due, hasDue, priority) {
                    taskDialog.openFor(id, taskText, due, hasDue, priority);
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

        onSaved: function(id, taskText, due, hasDue, priority) {
            var d = hasDue ? due : new Date(NaN);
            if (id <= 0) TaskModel.createTask(taskText, d, priority);
            else         TaskModel.updateTask(id, taskText, d, priority);
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
