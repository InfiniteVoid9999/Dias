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
    readonly property real headerHeight: 64

    signal createAt(date day, int hour)
    signal editEvent(int id, string evTitle, date start, date end, string category)
    signal editTask(int id, string taskText, date due, bool hasDue)

    // ---- date helpers ----
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

    readonly property var _weekdayShort: ["MON","TUE","WED","THU","FRI","SAT","SUN"]
    function _weekdayLabel(jsDay) { return _weekdayShort[(jsDay + 6) % 7]; }

    // ---- header: weekday + date pill per column ----
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

    Flickable {
        id: scroll
        anchors.top: headerRow.bottom
        anchors.topMargin: 1
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

            // hour axis labels (tabular mono)
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

            // day-column lanes + click-to-create
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

            // event blocks
            Repeater {
                model: EventModel
                delegate: Rectangle {
                    id: block
                    required property int id
                    required property string title
                    required property var start
                    required property var end
                    required property string category
                    required property string source
                    required property bool agentRecent

                    readonly property real startHours: start.getHours() + start.getMinutes() / 60
                    readonly property real rawDurHours: Math.max(0.25, (end - start) / 3600000)
                    readonly property real durHours: Math.min(rawDurHours, 24 - startHours)
                    readonly property int col: root._dayIndex(start)
                    readonly property color baseColor: Theme.categoryColor(category, source)
                    readonly property color textOn: Theme.onAccent

                    x: root.axisWidth + col * gridContent.laneWidth + Theme.sp1
                    y: startHours * root.hourHeight
                    width: gridContent.laneWidth - Theme.sp2
                    height: Math.max(durHours * root.hourHeight - 2, 24)
                    visible: col >= 0 && col < root.dayCount
                    radius: Theme.radiusEvent
                    color: Qt.alpha(baseColor, hoverHandler.hovered ? 1.0 : 0.88)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    // leading accent bar
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: Qt.darker(block.baseColor, 1.5)
                        radius: 1.5
                    }

                    // agent-edit pulse ring (PRD §7 visible-spine)
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
                            NumberAnimation { target: pulseRing; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                            NumberAnimation { target: pulseRing; property: "opacity"; from: 1; to: 0; duration: 1600; easing.type: Easing.InOutQuad }
                        }
                    }
                    onAgentRecentChanged: if (agentRecent) pulseAnim.restart()
                    Component.onCompleted: if (agentRecent) pulseAnim.restart()

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.sp1 + 2
                        anchors.leftMargin: Theme.sp2 + 4
                        spacing: 2

                        Text {
                            width: parent.width
                            text: block.title === "" ? "(untitled)" : block.title
                            color: block.textOn
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
                            text: Qt.formatTime(block.start, "HH:mm") + " – " + Qt.formatTime(block.end, "HH:mm")
                            color: block.textOn
                            opacity: 0.7
                            font.family: Theme.monoStack[0]
                            font.pixelSize: Theme.textCaption - 1
                        }
                    }

                    HoverHandler { id: hoverHandler }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editEvent(block.id, block.title, block.start, block.end, block.category)
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
                        color: Qt.alpha(pill.baseColor, hover.hovered ? 1.0 : 0.85)
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

                        HoverHandler { id: hover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.editTask(pill.id, pill.text, pill.due, pill.hasDue)
                        }

                        // agent-edit pulse
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
