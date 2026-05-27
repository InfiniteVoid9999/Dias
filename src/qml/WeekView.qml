import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

Item {
    id: root

    property date viewStart: EventModel.viewStart
    property int dayCount: EventModel.viewDays
    property real hourHeight: 56
    readonly property real axisWidth: 56
    readonly property real headerHeight: 60

    signal createAt(date day, int hour)
    signal editEvent(int id, string evTitle, date start, date end, string category)
    signal editTask(int id, string taskText, date due, bool hasDue)

    function _localMidnight(d) {
        var x = new Date(d);
        x.setHours(0, 0, 0, 0);
        return x;
    }

    function _mondayOf(d) {
        var x = _localMidnight(d);
        var dow = (x.getDay() + 6) % 7;
        x.setDate(x.getDate() - dow);
        return x;
    }

    function next() {
        var d = new Date(root.viewStart);
        d.setDate(d.getDate() + root.dayCount);
        EventModel.viewStart = d;
    }
    function prev() {
        var d = new Date(root.viewStart);
        d.setDate(d.getDate() - root.dayCount);
        EventModel.viewStart = d;
    }
    function gotoToday() {
        EventModel.viewStart = root.dayCount === 1
                               ? _localMidnight(new Date())
                               : _mondayOf(new Date());
    }

    function _dayIndex(d) {
        var a = _localMidnight(root.viewStart);
        var b = _localMidnight(d);
        return Math.round((b - a) / 86400000);
    }

    function _inRange(d) {
        var i = _dayIndex(d);
        return i >= 0 && i < root.dayCount;
    }

    readonly property var _weekdayShort: ["MON","TUE","WED","THU","FRI","SAT","SUN"]
    function _weekdayLabel(jsDay) {
        // js Date.getDay: Sun=0..Sat=6  →  remap to Mon=0..Sun=6
        return _weekdayShort[(jsDay + 6) % 7];
    }

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
                    spacing: 4
                    Text {
                        text: root._weekdayLabel(parent.parent.day.getDay())
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.letterSpacing: 1.2
                        opacity: 0.55
                        color: Material.foreground
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: parent.parent.isToday ? Material.accent : "transparent"
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            anchors.centerIn: parent
                            text: parent.parent.parent.day.getDate()
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            color: parent.parent.parent.isToday ? "#11111b" : Material.foreground
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
        color: Material.foreground
        opacity: 0.08
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

            Repeater {
                model: 24
                Text {
                    x: 4
                    y: index * root.hourHeight - height / 2
                    width: root.axisWidth - 8
                    text: (index < 10 ? "0" : "") + index
                    color: Material.foreground
                    opacity: 0.45
                    font.pixelSize: 11
                    font.family: "monospace"
                    horizontalAlignment: Text.AlignRight
                    visible: index > 0
                }
            }

            Repeater {
                model: 25
                Rectangle {
                    x: root.axisWidth
                    y: index * root.hourHeight
                    width: gridContent.width - root.axisWidth
                    height: 1
                    color: Material.foreground
                    opacity: 0.06
                }
            }

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
                            width: 1
                            height: parent.height
                            color: Material.foreground
                            opacity: 0.06
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: function(mouse) {
                                var hour = Math.max(0, Math.min(23, Math.floor(mouse.y / root.hourHeight)));
                                root.createAt(dayCol.day, hour);
                            }
                        }
                    }
                }
            }

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

                    readonly property real startHours: start.getHours() + start.getMinutes() / 60
                    readonly property real rawDurHours: Math.max(0.25, (end - start) / 3600000)
                    readonly property real durHours: Math.min(rawDurHours, 24 - startHours)
                    readonly property int col: root._dayIndex(start)
                    readonly property color baseColor: source === "agent" ? "#f9e2af"
                                                     : source === "gcal"  ? "#89dceb"
                                                                          : Material.accent

                    x: root.axisWidth + col * gridContent.laneWidth + 3
                    y: startHours * root.hourHeight
                    width: gridContent.laneWidth - 6
                    height: Math.max(durHours * root.hourHeight - 2, 22)
                    visible: col >= 0 && col < root.dayCount
                    radius: 6
                    color: Qt.alpha(baseColor, 0.85)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: Qt.darker(block.baseColor, 1.5)
                        radius: 1.5
                    }

                    Text {
                        anchors.fill: parent
                        anchors.margins: 6
                        anchors.leftMargin: 10
                        text: block.title === "" ? "(untitled)" : block.title
                        color: "#11111b"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignTop
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editEvent(block.id, block.title, block.start, block.end, block.category)
                    }
                }
            }

            Repeater {
                model: TaskModel
                delegate: Item {
                    id: pill
                    required property int id
                    required property string text
                    required property var due
                    required property bool hasDue
                    required property bool done

                    readonly property int col: hasDue ? root._dayIndex(due) : -1
                    readonly property real startHours: hasDue ? (due.getHours() + due.getMinutes() / 60) : 0

                    visible: hasDue && col >= 0 && col < root.dayCount
                    x: root.axisWidth + col * gridContent.laneWidth + 3
                    y: startHours * root.hourHeight
                    width: gridContent.laneWidth - 6
                    height: 24

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Qt.alpha(pill.done ? "#a6e3a1" : "#fab387", 0.85)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 6
                            width: 12; height: 12; radius: 6
                            border.color: "#11111b"
                            border.width: 1.4
                            color: pill.done ? "#11111b" : "transparent"
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 24
                            anchors.rightMargin: 8
                            text: pill.text
                            color: "#11111b"
                            opacity: pill.done ? 0.5 : 1.0
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            font.strikeout: pill.done
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.editTask(pill.id, pill.text, pill.due, pill.hasDue)
                        }
                    }
                }
            }

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
                    color: Material.accent
                }
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: Material.accent
                    y: -3
                    x: -4
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
