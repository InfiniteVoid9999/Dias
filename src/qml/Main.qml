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
    onUserThemeChanged: Settings.set("ui/userTheme", userTheme)

    // Restore + then persist subsequent changes.
    Component.onCompleted: {
        userTheme = Settings.get("ui/userTheme", 0);
        Theme.dark = _isDark;
        var savedMode = Settings.get("ui/viewMode", "week");
        if (savedMode === "day")        setDayView();
        else if (savedMode === "month") setMonthView();
        else if (savedMode === "year")  setYearView();
        // week is the default — already set in main.cpp
    }
    onViewModeChanged: Settings.set("ui/viewMode", viewMode)

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
    Shortcut { sequences: ["Ctrl+F", "/"]; enabled: !editDialog.visible && !taskDialog.visible; onActivated: searchPopup.openSearch() }
    Shortcut { sequences: ["N", "Ctrl+N"]; enabled: !editDialog.visible && !taskDialog.visible && !quickAddPopup.visible; onActivated: quickAddPopup.openQuick() }
    Shortcut { sequences: ["Y"];           enabled: !editDialog.visible && !taskDialog.visible; onActivated: setYearView() }
    Shortcut { sequences: ["?", "Shift+/"]; enabled: !editDialog.visible && !taskDialog.visible; onActivated: helpPopup.open() }

    function currentView() {
        return viewLoader.item;
    }
    function jumpToDate(d) {
        var anchor;
        if (root.viewMode === "day")        { anchor = _localMidnight(d); EventModel.viewStart = anchor; }
        else if (root.viewMode === "week")  { anchor = _mondayOf(d);      EventModel.viewStart = anchor; }
        else if (root.viewMode === "month") { anchor = _firstMondayOfMonthGrid(d); EventModel.viewStart = anchor; }
        else if (root.viewMode === "year")  { EventModel.viewStart = new Date(d.getFullYear(), 0, 1); }
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
    function setYearView() {
        var seed;
        if (viewMode === "month") {
            seed = new Date(EventModel.viewStart);
            seed.setDate(seed.getDate() + 14);
        } else {
            seed = (viewMode === "day" || viewMode === "week") ? EventModel.viewStart : new Date();
        }
        var jan1 = new Date(seed.getFullYear(), 0, 1);
        viewMode = "year";
        EventModel.viewStart = jan1;
        EventModel.viewDays = 366;
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
    function doIcsSync() { icsDialog.open(); }
    function _runIcsSync(url) {
        var r = Ics.ingestUrl(url, 15000);
        if (r.ok) {
            statusPopup.show("ICS: " + r.imported + " imported, "
                             + r.updated + " updated, " + r.skipped + " skipped");
            EventModel.reload();
            Settings.set("ics/lastUrl", url);
        } else {
            statusPopup.show("ICS sync failed: " + r.error);
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
                id: headerDate
                anchors.left: parent.left
                anchors.leftMargin: Theme.sp6
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp1

                Text {
                    id: monthYearLabel
                    text: {
                        if (root.viewMode === "year") {
                            return EventModel.viewStart.getFullYear();
                        }
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
                    color: pickerHover.hovered ? Theme.accent : Theme.fg
                    Behavior on color { ColorAnimation { duration: 120 } }

                    HoverHandler { id: pickerHover }
                    TapHandler {
                        onTapped: miniCalPopup.open()
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                    }
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

                // segmented view toggle (4-way: Day / Week / Month / Year)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 36
                    width: 240
                    radius: Theme.radiusPill
                    color: Theme.surface

                    property real segWidth: (width - 6) / 4

                    Rectangle {
                        id: segHighlight
                        width: parent.segWidth
                        height: parent.height - 6
                        y: 3
                        radius: Theme.radiusPill
                        color: Theme.accent
                        x: root.viewMode === "day"   ? 3
                          : root.viewMode === "week" ? 3 + parent.segWidth
                          : root.viewMode === "month"? 3 + 2 * parent.segWidth
                                                     : 3 + 3 * parent.segWidth
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: 3

                        Repeater {
                            model: [
                                { mode: "day",   label: "Day"   },
                                { mode: "week",  label: "Week"  },
                                { mode: "month", label: "Month" },
                                { mode: "year",  label: "Year"  }
                            ]
                            delegate: Item {
                                required property var modelData
                                width: parent.width / 4
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
                                        if (modelData.mode === "day")        setDayView();
                                        else if (modelData.mode === "week")  setWeekView();
                                        else if (modelData.mode === "month") setMonthView();
                                        else if (modelData.mode === "year")  setYearView();
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
                    glyph: "bolt"
                    ToolTip.text: "Quick add (N) — natural language"
                    emphasized: true
                    onClicked: quickAddPopup.openQuick()
                }
                IconBtn {
                    glyph: "search"
                    ToolTip.text: "Search (Ctrl+F or /)"
                    onClicked: searchPopup.openSearch()
                }
                IconBtn {
                    glyph: "hub"
                    ToolTip.text: "Sync from Obsidian vault"
                    onClicked: doObsidianSync()
                }
                IconBtn {
                    glyph: "rss_feed"
                    ToolTip.text: "Subscribe to .ics URL (read-only feed)"
                    onClicked: doIcsSync()
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
                sourceComponent: root.viewMode === "month" ? monthComp
                              : root.viewMode === "year"  ? yearComp
                                                          : weekComp
            }

            Component {
                id: weekComp
                WeekView {
                    onCreateAt: function(day, hour) {
                        var s = new Date(day);
                        s.setHours(hour, 0, 0, 0);
                        var e = new Date(s);
                        e.setHours(s.getHours() + 1);
                        editDialog.openFor({ id: 0, start: s, end: e });
                    }
                    onEditEvent: function(args) {
                        editDialog.openFor(args);
                    }
                    onEditTask: function(id, taskText, due, hasDue, priority) {
                        taskDialog.openFor(id, taskText, due, hasDue, priority);
                    }
                }
            }

            Component {
                id: monthComp
                MonthView {
                    onEditEvent: function(args) {
                        editDialog.openFor(args);
                    }
                    onSelectDay: function(day) {
                        EventModel.viewStart = day;
                        EventModel.viewDays = 1;
                        root.viewMode = "day";
                    }
                }
            }

            Component {
                id: yearComp
                YearView {
                    onSelectMonth: function(monthAnchor) {
                        EventModel.viewStart = _firstMondayOfMonthGrid(monthAnchor);
                        EventModel.viewDays = 42;
                        root.viewMode = "month";
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

        onSaved: function(id, evTitle, start, end, category, rrule, allDay, notes, loc, reminder) {
            if (id <= 0) EventModel.createEvent(evTitle, start, end, category, rrule, allDay, notes, loc, reminder);
            else         EventModel.updateEvent(id, evTitle, start, end, category, rrule, allDay, notes, loc, reminder);
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

    // -------- .ics URL subscription dialog --------
    Dialog {
        id: icsDialog
        modal: true
        width: 540
        padding: 0
        title: "Subscribe to .ics feed"
        anchors.centerIn: parent

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusCard
            border.color: Theme.border
            border.width: 1
        }

        header: Item {
            implicitHeight: 56
            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.sp6
                anchors.verticalCenter: parent.verticalCenter
                text: icsDialog.title
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textTitle
                font.weight: Theme.weightBold
                color: Theme.fg
            }
        }

        contentItem: ColumnLayout {
            spacing: Theme.sp3

            TextField {
                id: icsUrlField
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
                placeholderText: "https://… or webcal://…"
                font.family: Theme.monoStack[0]
                font.pixelSize: Theme.textBody
                Material.accent: Theme.accent
                color: Theme.fg
                Keys.onReturnPressed: icsSyncBtn.clicked()
                Keys.onEnterPressed: icsSyncBtn.clicked()
                Component.onCompleted: text = Settings.get("ics/lastUrl", "")
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
                text: "Re-syncing the same URL updates existing events in place via the UID mapping in sync_sources."
                wrapMode: Text.Wrap
                color: Theme.fgSubtle
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textCaption
            }

            Item { Layout.preferredHeight: Theme.sp1 }
        }

        footer: Item {
            implicitHeight: 64
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp4
                anchors.rightMargin: Theme.sp4
                spacing: Theme.sp2

                Item { Layout.fillWidth: true }
                Button {
                    text: "Cancel"
                    flat: true
                    Material.foreground: Theme.fgMuted
                    onClicked: icsDialog.close()
                }
                Button {
                    id: icsSyncBtn
                    text: "Sync"
                    highlighted: true
                    Material.accent: Theme.accent
                    Material.foreground: Theme.onAccent
                    enabled: icsUrlField.text.trim() !== ""
                    onClicked: {
                        _runIcsSync(icsUrlField.text.trim());
                        icsDialog.close();
                    }
                }
            }
        }
    }

    // -------- keyboard shortcuts overlay --------
    Popup {
        id: helpPopup
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: 520
        x: (root.width - width) / 2
        y: 120
        padding: 0

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusCard
            border.color: Theme.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.sp6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Keyboard shortcuts"
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textTitle
                    font.weight: Theme.weightBold
                    color: Theme.fg
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

            GridLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.sp5
                columns: 2
                rowSpacing: Theme.sp2
                columnSpacing: Theme.sp5

                // helper component for a kbd-style chip
                component Kbd: Rectangle {
                    property string label: ""
                    implicitWidth: kbdText.implicitWidth + Theme.sp3
                    implicitHeight: 22
                    radius: 4
                    color: Theme.bg
                    border.color: Theme.border
                    border.width: 1
                    Text {
                        id: kbdText
                        anchors.centerIn: parent
                        text: parent.label
                        font.family: Theme.monoStack[0]
                        font.pixelSize: Theme.textCaption
                        color: Theme.fgMuted
                    }
                }

                Repeater {
                    model: [
                        { keys: ["N"],                desc: "Quick add (natural language)" },
                        { keys: ["Ctrl+F", "/"],      desc: "Search events" },
                        { keys: ["?"],                desc: "This help" },
                        { keys: ["D"],                desc: "Day view" },
                        { keys: ["W"],                desc: "Week view" },
                        { keys: ["M"],                desc: "Month view" },
                        { keys: ["Y"],                desc: "Year view" },
                        { keys: ["T"],                desc: "Jump to today" },
                        { keys: ["←", "H"],           desc: "Previous period" },
                        { keys: ["→", "L"],           desc: "Next period" },
                        { keys: ["Ctrl+E"],           desc: "Export to ~/Dias/export/" },
                        { keys: ["Esc"],              desc: "Close dialog / quit" },
                        { keys: ["Enter"],            desc: "Submit dialog" }
                    ]
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp2
                        Row {
                            spacing: 4
                            Repeater {
                                model: modelData.keys
                                Kbd { label: modelData }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.desc
                            color: Theme.fg
                            font.family: Theme.sansStack[0]
                            font.pixelSize: Theme.textBody
                        }
                    }
                }
            }
        }
    }

    // -------- quick-add (natural language) --------
    QuickAddPopup {
        id: quickAddPopup
        parent: root.overlay

        onAccepted: function(qaTitle, start, end, allDay) {
            EventModel.createEvent(qaTitle, start, end, "", "", allDay, "", "", 0);
            statusPopup.show("Added: " + qaTitle);
            jumpToDate(start);
        }
    }

    // -------- search popup --------
    Popup {
        id: searchPopup
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: (root.width - width) / 2
        y: 96
        width: 540
        padding: 0

        property var results: []

        function openSearch() {
            searchField.text = "";
            results = [];
            open();
            searchField.forceActiveFocus();
        }

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusCard
            border.color: Theme.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.sp3
                spacing: Theme.sp2

                Text {
                    text: "search"
                    font.family: Theme.iconFont
                    font.pixelSize: 20
                    color: Theme.fgMuted
                }
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: "Search events…"
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textInput
                    Material.accent: Theme.accent
                    color: Theme.fg
                    background: null
                    onTextChanged: searchPopup.results = EventModel.search(text)
                    Keys.onEscapePressed: searchPopup.close()
                    Keys.onReturnPressed: {
                        if (searchPopup.results.length > 0) {
                            var r = searchPopup.results[0];
                            jumpToDate(r.start);
                            editDialog.openFor(r);
                            searchPopup.close();
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.divider
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(360, Math.max(40, searchPopup.results.length * 52))
                model: searchPopup.results
                clip: true
                ScrollBar.vertical: ScrollBar {}

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 52

                    Rectangle {
                        anchors.fill: parent
                        color: rowHov.hovered ? Theme.hoverTint : "transparent"
                        HoverHandler { id: rowHov }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                jumpToDate(modelData.start);
                                editDialog.openFor(modelData);
                                searchPopup.close();
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sp4
                        anchors.rightMargin: Theme.sp4
                        spacing: Theme.sp3

                        Rectangle {
                            Layout.preferredWidth: 4
                            Layout.preferredHeight: 32
                            radius: 2
                            color: Theme.categoryColor(modelData.category || "", modelData.source || "local")
                        }
                        Column {
                            Layout.fillWidth: true
                            Text {
                                text: modelData.title === "" ? "(untitled)" : modelData.title
                                color: Theme.fg
                                font.family: Theme.sansStack[0]
                                font.pixelSize: Theme.textBody
                                font.weight: Theme.weightMedium
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: Qt.formatDateTime(modelData.start, "ddd, d MMM yyyy · HH:mm")
                                color: Theme.fgMuted
                                font.family: Theme.sansStack[0]
                                font.pixelSize: Theme.textCaption
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: parent.count === 0 && searchField.text !== ""
                    text: "no matches"
                    color: Theme.fgSubtle
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textBody
                }
            }
        }
    }

    // -------- mini-calendar picker (click month label) --------
    Popup {
        id: miniCalPopup
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: 24
        y: 88
        width: 280
        padding: Theme.sp3

        property date pickerMonth: {
            if (root.viewMode === "month") {
                var d = new Date(EventModel.viewStart);
                d.setDate(d.getDate() + 14);
                return d;
            }
            return EventModel.viewStart;
        }
        function pickerNext()  { pickerMonth = (function(){ var d=new Date(pickerMonth); d.setMonth(d.getMonth()+1); return d; })() }
        function pickerPrev()  { pickerMonth = (function(){ var d=new Date(pickerMonth); d.setMonth(d.getMonth()-1); return d; })() }
        function firstCellDate() {
            var first = new Date(pickerMonth.getFullYear(), pickerMonth.getMonth(), 1);
            var dow = (first.getDay() + 6) % 7;
            var monday = new Date(first);
            monday.setDate(first.getDate() - dow);
            return monday;
        }

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusCard
            border.color: Theme.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: Theme.sp2

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp1

                Text {
                    Layout.fillWidth: true
                    text: Qt.formatDate(miniCalPopup.pickerMonth, "MMMM yyyy")
                    color: Theme.fg
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textBody
                    font.weight: Theme.weightBold
                }
                ToolButton {
                    text: "chevron_left"
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    Material.foreground: Theme.fgMuted
                    onClicked: miniCalPopup.pickerPrev()
                }
                ToolButton {
                    text: "chevron_right"
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    Material.foreground: Theme.fgMuted
                    onClicked: miniCalPopup.pickerNext()
                }
            }

            // weekday header row
            Row {
                Layout.fillWidth: true
                spacing: 0
                Repeater {
                    model: ["M","T","W","T","F","S","S"]
                    Item {
                        width: 280 / 7
                        height: 18
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.fgSubtle
                            font.family: Theme.sansStack[0]
                            font.pixelSize: Theme.textCaption
                            font.weight: Theme.weightMedium
                        }
                    }
                }
            }

            // 6×7 day grid
            Grid {
                Layout.fillWidth: true
                rows: 6
                columns: 7
                Repeater {
                    model: 42
                    Item {
                        required property int index
                        width: 280 / 7
                        height: 32
                        property date cellDay: {
                            var d = miniCalPopup.firstCellDate();
                            d.setDate(d.getDate() + index);
                            return d;
                        }
                        property bool inMonth: cellDay.getMonth() === miniCalPopup.pickerMonth.getMonth()
                        property bool isToday: {
                            var t = new Date();
                            return cellDay.getFullYear() === t.getFullYear()
                                && cellDay.getMonth() === t.getMonth()
                                && cellDay.getDate() === t.getDate();
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 28; height: 28
                            radius: Theme.radiusPill
                            color: isToday ? Theme.accent
                                  : cellHov.hovered ? Theme.hoverTint
                                  : "transparent"
                            HoverHandler { id: cellHov }
                            Text {
                                anchors.centerIn: parent
                                text: cellDay.getDate()
                                color: isToday ? Theme.onAccent
                                      : inMonth ? Theme.fg
                                      : Theme.fgSubtle
                                font.family: Theme.sansStack[0]
                                font.pixelSize: Theme.textCaption + 1
                                font.weight: isToday ? Theme.weightBold : Theme.weightRegular
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    jumpToDate(cellDay);
                                    miniCalPopup.close();
                                }
                            }
                        }
                    }
                }
            }
        }
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
