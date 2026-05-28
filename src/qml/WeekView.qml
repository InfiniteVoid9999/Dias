import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import Dias

Item {
    id: root

    property date viewStart: EventModel.viewStart
    property int dayCount: EventModel.viewDays
    property real hourHeight: 56
    readonly property real axisWidth: 60
    readonly property real headerHeight: 60
    readonly property real allDayRowH: 24

    signal createAt(date day, int hour)
    signal editEvent(var args)
    signal editTask(int id, string taskText, date due, bool hasDue, int priority)

    function _localMidnight(d) { var x = new Date(d); x.setHours(0,0,0,0); return x; }
    function _mondayOf(d) {
        var x = _localMidnight(d);
        var dow = (x.getDay() + 6) % 7;
        x.setDate(x.getDate() - dow);
        return x;
    }
    function next() {
        var d = new Date(root.viewStart); d.setDate(d.getDate() + root.dayCount);
        EventModel.viewStart = d;
    }
    function prev() {
        var d = new Date(root.viewStart); d.setDate(d.getDate() - root.dayCount);
        EventModel.viewStart = d;
    }
    function gotoToday() {
        EventModel.viewStart = root.dayCount === 1 ? _localMidnight(new Date()) : _mondayOf(new Date());
    }
    function _dayIndex(d) {
        var a = _localMidnight(root.viewStart);
        var b = _localMidnight(d);
        return Math.round((b - a) / 86400000);
    }
    function _snap15(hour) {
        return Math.round(hour * 4) / 4;
    }

    readonly property var _weekdayShort: ["MON","TUE","WED","THU","FRI","SAT","SUN"]
    function _weekdayLabel(jsDay) { return _weekdayShort[(jsDay + 6) % 7]; }

    // -------- day-header row --------
    Row {
        id: headerRow
        x: root.axisWidth
        width: root.width - root.axisWidth
        height: root.headerHeight
        spacing: 0

        Repeater {
            model: root.dayCount
            Item {
                width: headerRow.width / root.dayCount
                height: headerRow.height

                property date day: {
                    var d = new Date(root.viewStart);
                    d.setDate(d.getDate() + index);
                    return d;
                }
                property bool isToday: {
                    var t = new Date();
                    return day.getFullYear() === t.getFullYear()
                        && day.getMonth() === t.getMonth()
                        && day.getDate() === t.getDate();
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.sp1
                    Text {
                        text: root._weekdayLabel(parent.parent.day.getDay())
                        font.family: Theme.sansStack[0]
                        font.pixelSize: Theme.textCaption
                        font.weight: Theme.weightMedium
                        font.letterSpacing: 1.2
                        color: parent.parent.isToday ? Theme.accent : Theme.fgMuted
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Rectangle {
                        width: 34; height: 34
                        radius: Theme.radiusPill
                        color: parent.parent.isToday ? Theme.accent : "transparent"
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            anchors.centerIn: parent
                            text: parent.parent.parent.day.getDate()
                            font.family: Theme.sansStack[0]
                            font.pixelSize: 16
                            font.weight: Theme.weightMedium
                            color: parent.parent.parent.isToday ? Theme.onAccent : Theme.fg
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.divider
    }

    // -------- all-day banner --------
    // One row per all-day event currently visible, spanning the days it covers.
    Item {
        id: allDayBanner
        anchors.top: headerRow.bottom
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(0, _visibleAllDayCount * root.allDayRowH + 4)
        visible: height > 4

        property int _visibleAllDayCount: EventModel.visibleAllDayCount()
        Connections {
            target: EventModel
            function onModelReset() { allDayBanner._visibleAllDayCount = EventModel.visibleAllDayCount(); }
        }

        // Stacked rows for the actual visible all-day events.
        Repeater {
            model: EventModel
            delegate: Rectangle {
                id: adBlock
                required property int index
                required property int id
                required property string title
                required property var start
                required property var end
                required property string category
                required property string source
                required property bool agentRecent
                required property bool allDay
                required property string rrule
                required property string notes
                required property string location
                required property int reminderMinutes

                readonly property color baseColor: Theme.categoryColor(category, source)
                readonly property int startCol: Math.max(0, root._dayIndex(start))
                readonly property int endCol: Math.min(root.dayCount - 1, root._dayIndex(end))
                readonly property real laneW: (root.width - root.axisWidth) / root.dayCount
                readonly property int rowIndex: EventModel.allDayPositionOf(id)

                visible: allDay && endCol >= 0 && startCol < root.dayCount
                x: root.axisWidth + startCol * laneW + 2
                y: 2 + rowIndex * root.allDayRowH
                width: Math.max(40, (endCol - startCol + 1) * laneW - 4)
                height: root.allDayRowH - 2
                radius: 4
                color: Qt.alpha(baseColor, 0.85)

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    text: (adBlock.title === "" ? "(untitled)" : adBlock.title)
                    color: Theme.onAccent
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textCaption
                    font.weight: Theme.weightMedium
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.editEvent({
                        id: adBlock.id, title: adBlock.title,
                        start: adBlock.start, end: adBlock.end,
                        category: adBlock.category, source: adBlock.source,
                        rrule: adBlock.rrule, allDay: adBlock.allDay,
                        notes: adBlock.notes, location: adBlock.location,
                        reminderMinutes: adBlock.reminderMinutes
                    })
                }
            }
        }
    }

    // -------- scrollable hour grid --------
    Flickable {
        id: scroll
        anchors.top: allDayBanner.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: gridContent.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Component.onCompleted: contentY = Math.max(0, 7 * root.hourHeight - 20)

        Item {
            id: gridContent
            width: scroll.width
            height: 24 * root.hourHeight

            readonly property real laneWidth: (width - root.axisWidth) / root.dayCount

            // hour axis labels
            Repeater {
                model: 24
                Text {
                    x: 4
                    y: index * root.hourHeight - height / 2
                    width: root.axisWidth - Theme.sp2
                    text: (index < 10 ? "0" : "") + index
                    color: Theme.fgSubtle
                    font.family: Theme.monoStack[0]
                    font.pixelSize: Theme.textCaption
                    horizontalAlignment: Text.AlignRight
                    visible: index > 0
                }
            }

            // hour gridlines
            Repeater {
                model: 25
                Rectangle {
                    x: root.axisWidth
                    y: index * root.hourHeight
                    width: gridContent.width - root.axisWidth
                    height: 1
                    color: Theme.gridLine
                }
            }

            // day lanes + click-to-create
            Row {
                x: root.axisWidth
                width: gridContent.width - root.axisWidth
                height: gridContent.height
                spacing: 0

                Repeater {
                    model: root.dayCount
                    Item {
                        id: dayCol
                        property date day: {
                            var d = new Date(root.viewStart);
                            d.setDate(d.getDate() + index);
                            d.setHours(0, 0, 0, 0);
                            return d;
                        }
                        width: gridContent.laneWidth
                        height: gridContent.height

                        Rectangle {
                            visible: index > 0
                            width: 1; height: parent.height
                            color: Theme.gridLine
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: function(mouse) {
                                var hour = Math.max(0, Math.min(23, Math.floor(mouse.y / root.hourHeight)));
                                root.createAt(dayCol.day, hour);
                            }
                        }
                    }
                }
            }

            // events — one outer delegate per row, inner Repeater for day segments
            Repeater {
                model: EventModel
                delegate: Item {
                    id: row
                    required property int id
                    required property string title
                    required property var start
                    required property var end
                    required property string category
                    required property string source
                    required property bool agentRecent
                    required property bool allDay
                    required property string rrule
                    required property string notes
                    required property string location
                    required property int reminderMinutes

                    visible: !allDay
                    anchors.fill: parent

                    readonly property color baseColor: Theme.categoryColor(category, source)
                    readonly property bool isRecurringInstance: rrule !== ""

                    // Build per-day segments for events that span multiple days.
                    property var segments: _buildSegments()
                    function _buildSegments() {
                        var out = [];
                        if (allDay) return out;
                        var firstCol = Math.max(0, root._dayIndex(start));
                        var lastCol  = Math.min(root.dayCount - 1, root._dayIndex(end));
                        if (lastCol < 0 || firstCol >= root.dayCount) return out;
                        // If end falls exactly at next-day midnight, drop the trailing
                        // empty segment (end is exclusive in human terms).
                        if (end.getHours() === 0 && end.getMinutes() === 0 && lastCol > firstCol) {
                            lastCol -= 1;
                        }
                        for (var c = firstCol; c <= lastCol; c++) {
                            var dayStart = new Date(root.viewStart);
                            dayStart.setDate(dayStart.getDate() + c);
                            dayStart.setHours(0, 0, 0, 0);
                            var dayEnd = new Date(dayStart);
                            dayEnd.setDate(dayEnd.getDate() + 1);

                            var segStart = c === firstCol ? start : dayStart;
                            var segEnd   = c === lastCol  ? end   : dayEnd;
                            var sh = segStart.getHours() + segStart.getMinutes() / 60;
                            var eh = segEnd.getHours()   + segEnd.getMinutes()   / 60;
                            if (eh === 0 && c === lastCol && segEnd > dayStart) eh = 24;
                            out.push({ col: c, startHours: sh, durHours: Math.max(0.25, eh - sh) });
                        }
                        return out;
                    }

                    Repeater {
                        model: row.segments.length
                        delegate: Rectangle {
                            id: block
                            required property int index
                            readonly property var seg: row.segments[index]

                            // overlap-aware lane packing: query the model once per day-segment
                            readonly property var laneInfo: EventModel.overlapLane(row.id)
                            readonly property int laneIdx: laneInfo.lane || 0
                            readonly property int laneCount: Math.max(1, laneInfo.lanes || 1)
                            readonly property real slotW: (gridContent.laneWidth - Theme.sp2) / laneCount

                            // natural position from model
                            readonly property real naturalX: root.axisWidth + seg.col * gridContent.laneWidth + Theme.sp1 + laneIdx * slotW
                            readonly property real naturalY: seg.startHours * root.hourHeight
                            readonly property real naturalH: Math.max(seg.durHours * root.hourHeight - 2, 24)

                            x: dragArea.dragging ? dragArea.dragX : naturalX
                            y: dragArea.dragging ? dragArea.dragY : naturalY
                            width: dragArea.dragging ? (gridContent.laneWidth - Theme.sp2) : slotW
                            height: resizeArea.resizing
                                    ? Math.max(20, resizeArea.resizeH)
                                    : naturalH
                            radius: Theme.radiusEvent
                            color: Qt.alpha(row.baseColor, hover.hovered ? 1.0 : 0.88)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            opacity: dragArea.dragging ? 0.85 : 1.0
                            z: dragArea.dragging ? 50 : 1

                            // leading accent
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 3
                                color: Qt.darker(row.baseColor, 1.5)
                                radius: 1.5
                            }

                            // recurring badge
                            Rectangle {
                                visible: row.isRecurringInstance
                                width: 14; height: 14; radius: 7
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 4
                                color: Qt.darker(row.baseColor, 1.5)
                                Text {
                                    anchors.centerIn: parent
                                    text: "autorenew"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 10
                                    color: Theme.onAccent
                                }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.sp1 + 2
                                anchors.leftMargin: Theme.sp2 + 4
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: row.title === "" ? "(untitled)" : row.title
                                    color: Theme.onAccent
                                    font.family: Theme.sansStack[0]
                                    font.pixelSize: Theme.textBody
                                    font.weight: Theme.weightMedium
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideRight
                                    maximumLineCount: block.height > 44 ? 3 : 1
                                }
                                Text {
                                    visible: block.height > 36
                                    width: parent.width
                                    text: Qt.formatTime(row.start, "HH:mm") + " – " + Qt.formatTime(row.end, "HH:mm")
                                    color: Theme.onAccent
                                    opacity: 0.7
                                    font.family: Theme.monoStack[0]
                                    font.pixelSize: Theme.textCaption - 1
                                }
                                Text {
                                    visible: block.height > 60 && row.location !== ""
                                    width: parent.width
                                    text: "📍 " + row.location
                                    color: Theme.onAccent
                                    opacity: 0.8
                                    font.family: Theme.sansStack[0]
                                    font.pixelSize: Theme.textCaption - 1
                                    elide: Text.ElideRight
                                }
                            }

                            HoverHandler { id: hover }

                            // drag-to-reschedule (disabled for RRULE instances to avoid surprise)
                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                anchors.bottomMargin: 8  // leave room for resize handle
                                cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                hoverEnabled: true

                                property bool dragging: false
                                property real dragX: 0
                                property real dragY: 0
                                property real pressX: 0
                                property real pressY: 0
                                property real moveThreshold: 4

                                onPressed: function(mouse) {
                                    pressX = mouse.x; pressY = mouse.y;
                                    dragX = block.naturalX; dragY = block.naturalY;
                                }
                                onPositionChanged: function(mouse) {
                                    if (row.isRecurringInstance) return;
                                    if (!pressed) return;
                                    var dx = mouse.x - pressX;
                                    var dy = mouse.y - pressY;
                                    if (!dragging && Math.abs(dx) + Math.abs(dy) > moveThreshold) {
                                        dragging = true;
                                    }
                                    if (dragging) {
                                        dragX = block.naturalX + dx;
                                        dragY = Math.max(0, Math.min(24 * root.hourHeight - 20, block.naturalY + dy));
                                    }
                                }
                                onReleased: function(mouse) {
                                    if (!dragging) {
                                        // treat as click → open editor
                                        root.editEvent({
                                            id: row.id, title: row.title,
                                            start: row.start, end: row.end,
                                            category: row.category, source: row.source,
                                            rrule: row.rrule, allDay: row.allDay,
                                            notes: row.notes, location: row.location,
                                            reminderMinutes: row.reminderMinutes
                                        });
                                        return;
                                    }
                                    dragging = false;
                                    // figure out target day + hour
                                    var newCol = Math.max(0, Math.min(root.dayCount - 1,
                                        Math.floor((dragX - root.axisWidth + gridContent.laneWidth / 2) / gridContent.laneWidth)));
                                    var newHourF = root._snap15(dragY / root.hourHeight);
                                    var newDate = new Date(root.viewStart);
                                    newDate.setDate(newDate.getDate() + newCol);
                                    newDate.setHours(Math.floor(newHourF), (newHourF % 1) * 60, 0, 0);
                                    EventModel.moveEvent(row.id, newDate);
                                }
                            }

                            // drag-to-resize (bottom edge)
                            MouseArea {
                                id: resizeArea
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 8
                                cursorShape: Qt.SizeVerCursor
                                hoverEnabled: true
                                visible: !row.isRecurringInstance

                                property bool resizing: false
                                property real resizeH: 0
                                property real pressY: 0

                                onPressed: function(mouse) {
                                    pressY = mouse.y;
                                    resizeH = block.naturalH;
                                }
                                onPositionChanged: function(mouse) {
                                    if (!pressed) return;
                                    resizing = true;
                                    var dy = mouse.y - pressY;
                                    resizeH = Math.max(24, block.naturalH + dy);
                                }
                                onReleased: function(mouse) {
                                    if (!resizing) return;
                                    resizing = false;
                                    var endHoursF = root._snap15((block.naturalY + resizeH) / root.hourHeight);
                                    var newEnd = new Date(row.start);
                                    newEnd.setHours(Math.floor(endHoursF), (endHoursF % 1) * 60, 0, 0);
                                    if (newEnd <= row.start) newEnd = new Date(row.start.getTime() + 15 * 60000);
                                    EventModel.resizeEvent(row.id, newEnd);
                                }
                            }

                            // agent-edit pulse
                            Rectangle {
                                id: pulseRing
                                anchors.fill: parent
                                anchors.margins: -3
                                radius: parent.radius + 3
                                color: "transparent"
                                border.color: Theme.accent
                                border.width: 2
                                opacity: 0
                                z: 2
                                SequentialAnimation {
                                    id: pulseAnim
                                    NumberAnimation { target: pulseRing; property: "opacity"; from: 0; to: 1; duration: 220 }
                                    NumberAnimation { target: pulseRing; property: "opacity"; from: 1; to: 0; duration: 1600 }
                                }
                            }
                            Connections {
                                target: row
                                function onAgentRecentChanged() { if (row.agentRecent) pulseAnim.restart(); }
                            }
                            Component.onCompleted: if (row.agentRecent) pulseAnim.restart()
                        }
                    }
                }
            }

            // task pills
            Repeater {
                model: TaskModel
                delegate: Item {
                    id: pill
                    required property int id
                    required property string text
                    required property var due
                    required property bool hasDue
                    required property bool done
                    required property bool agentRecent
                    required property int priority

                    readonly property int col: hasDue ? root._dayIndex(due) : -1
                    readonly property real startHours: hasDue ? (due.getHours() + due.getMinutes() / 60) : 0
                    readonly property color baseColor: done ? Theme.taskDone : Theme.taskPending

                    visible: hasDue && col >= 0 && col < root.dayCount
                    x: root.axisWidth + col * gridContent.laneWidth + Theme.sp1
                    y: startHours * root.hourHeight
                    width: gridContent.laneWidth - Theme.sp2
                    height: 26

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusPill
                        color: Qt.alpha(pill.baseColor, taskHover.hovered ? 1.0 : 0.85)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 7
                            width: 13; height: 13
                            radius: Theme.radiusPill
                            border.color: Theme.onTaskPill
                            border.width: 1.4
                            color: pill.done ? Theme.onTaskPill : "transparent"
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 26
                            anchors.rightMargin: Theme.sp2
                            text: pill.text
                            color: Theme.onTaskPill
                            opacity: pill.done ? Theme.doneOpacity : 1.0
                            font.family: Theme.sansStack[0]
                            font.pixelSize: Theme.textCaption + 1
                            font.weight: Theme.weightMedium
                            font.strikeout: pill.done
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        HoverHandler { id: taskHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.editTask(pill.id, pill.text, pill.due, pill.hasDue, pill.priority)
                        }

                        Rectangle {
                            id: taskPulseRing
                            anchors.fill: parent
                            anchors.margins: -3
                            radius: parent.radius + 3
                            color: "transparent"
                            border.color: Theme.accent
                            border.width: 2
                            opacity: 0
                            z: 2
                            SequentialAnimation {
                                id: taskPulseAnim
                                NumberAnimation { target: taskPulseRing; property: "opacity"; from: 0; to: 1; duration: 220 }
                                NumberAnimation { target: taskPulseRing; property: "opacity"; from: 1; to: 0; duration: 1600 }
                            }
                        }
                        Connections {
                            target: pill
                            function onAgentRecentChanged() { if (pill.agentRecent) taskPulseAnim.restart(); }
                        }
                        Component.onCompleted: if (pill.agentRecent) taskPulseAnim.restart()
                    }
                }
            }

            // empty-state hint: shown only if there are literally no events
            // anywhere in the visible week and no tasks. Doesn't compete with
            // any content — just appears when the canvas is blank.
            Column {
                anchors.centerIn: parent
                visible: EventModel.rowCount() === 0 && TaskModel.rowCount() === 0
                spacing: Theme.sp3
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "auto_awesome"
                    font.family: Theme.iconFont
                    font.pixelSize: 36
                    color: Theme.fgSubtle
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "your calendar is empty"
                    color: Theme.fgMuted
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textBody
                    font.weight: Theme.weightMedium
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "press  N  for quick add  ·  ?  for shortcuts  ·  Ctrl+K  for command palette"
                    color: Theme.fgSubtle
                    font.family: Theme.monoStack[0]
                    font.pixelSize: Theme.textCaption
                }
            }

            // now-line
            Item {
                id: nowMarker
                property date now: new Date()
                property bool inThisView: {
                    var ws = root.viewStart;
                    var we = new Date(ws); we.setDate(we.getDate() + root.dayCount);
                    return now >= ws && now < we;
                }
                visible: inThisView
                x: root.axisWidth
                width: gridContent.width - root.axisWidth
                y: (now.getHours() + now.getMinutes() / 60) * root.hourHeight - 1

                Rectangle {
                    width: parent.width
                    height: 2
                    color: Theme.accent
                }
                Rectangle {
                    width: 10; height: 10
                    radius: Theme.radiusPill
                    color: Theme.accent
                    y: -4
                    x: -5
                }

                Timer {
                    interval: 60000
                    repeat: true
                    running: true
                    onTriggered: nowMarker.now = new Date()
                }
            }
        }
    }
}
