import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Dias

// 12 mini-month grids in a 4×3 arrangement. Click a month → switch to Month
// view at that month. Click a day → switch to Day view at that date.
// EventStartedHere markers (small dots) appear under day numbers that have
// any event starting on that day in the visible year.
Item {
    id: root

    property date viewStart: EventModel.viewStart
    readonly property int viewYear: viewStart.getFullYear()

    signal selectMonth(date monthAnchor)

    function next()  { var d = new Date(viewStart); d.setFullYear(d.getFullYear() + 1); EventModel.viewStart = new Date(d.getFullYear(), 0, 1); }
    function prev()  { var d = new Date(viewStart); d.setFullYear(d.getFullYear() - 1); EventModel.viewStart = new Date(d.getFullYear(), 0, 1); }
    function gotoToday() {
        var now = new Date();
        EventModel.viewStart = new Date(now.getFullYear(), 0, 1);
    }

    function _firstMondayOf(month, year) {
        var first = new Date(year, month, 1);
        var dow = (first.getDay() + 6) % 7;
        var monday = new Date(first);
        monday.setDate(first.getDate() - dow);
        monday.setHours(0, 0, 0, 0);
        return monday;
    }

    // Build a Set of YYYY-MM-DD strings for days with events, computed from the
    // visible model. Recomputes on model reset.
    property var _dayHasEvent: ({})
    Connections {
        target: EventModel
        function onModelReset() { root._rebuildEventDayMap(); }
    }
    Component.onCompleted: _rebuildEventDayMap()

    function _rebuildEventDayMap() {
        var m = {};
        var n = EventModel.rowCount();
        for (var i = 0; i < n; i++) {
            var idx = EventModel.index(i, 0);
            var s = EventModel.data(idx, 258);   // StartRole = UserRole(256) + 2
            if (!s) continue;
            var d = new Date(s);
            var key = d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
            m[key] = true;
        }
        _dayHasEvent = m;
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: Theme.sp4
        contentWidth: availableWidth

        GridLayout {
            width: parent.parent.availableWidth
            columns: 4
            rowSpacing: Theme.sp4
            columnSpacing: Theme.sp4

            Repeater {
                model: 12
                delegate: Item {
                    id: monthCell
                    required property int index
                    readonly property int month: index
                    readonly property int year: root.viewYear
                    readonly property date monthAnchor: new Date(year, month, 1)
                    Layout.fillWidth: true
                    Layout.preferredHeight: width * 0.85

                    Rectangle {
                        anchors.fill: parent
                        color: monthHover.hovered ? Theme.hoverTint : "transparent"
                        radius: Theme.radiusCard
                        Behavior on color { ColorAnimation { duration: 120 } }
                        HoverHandler { id: monthHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectMonth(monthCell.monthAnchor)
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.sp2
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: Qt.formatDate(monthCell.monthAnchor, "MMMM")
                            color: Theme.fg
                            font.family: Theme.sansStack[0]
                            font.pixelSize: Theme.textBody
                            font.weight: Theme.weightBold
                        }

                        Row {
                            Layout.fillWidth: true
                            spacing: 0
                            Repeater {
                                model: ["M","T","W","T","F","S","S"]
                                Item {
                                    width: parent.parent.parent.width / 7
                                    height: 14
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: Theme.fgSubtle
                                        font.family: Theme.sansStack[0]
                                        font.pixelSize: Theme.textCaption - 2
                                        font.weight: Theme.weightMedium
                                    }
                                }
                            }
                        }

                        Grid {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            rows: 6
                            columns: 7
                            Repeater {
                                model: 42
                                delegate: Item {
                                    required property int index
                                    width: parent.width / 7
                                    height: parent.height / 6
                                    property date cellDay: {
                                        var first = root._firstMondayOf(monthCell.month, monthCell.year);
                                        first.setDate(first.getDate() + index);
                                        return first;
                                    }
                                    property bool inMonth: cellDay.getMonth() === monthCell.month
                                    property bool isToday: {
                                        var t = new Date();
                                        return cellDay.getFullYear() === t.getFullYear()
                                            && cellDay.getMonth() === t.getMonth()
                                            && cellDay.getDate() === t.getDate();
                                    }
                                    property string dayKey: cellDay.getFullYear() + "-" + (cellDay.getMonth() + 1) + "-" + cellDay.getDate()
                                    property bool hasEvent: root._dayHasEvent[dayKey] === true && inMonth

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height) - 2
                                        height: width
                                        radius: Theme.radiusPill
                                        color: parent.isToday ? Theme.accent : "transparent"
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.cellDay.getDate()
                                        color: parent.isToday ? Theme.onAccent
                                              : parent.inMonth ? Theme.fg : Theme.fgSubtle
                                        font.family: Theme.sansStack[0]
                                        font.pixelSize: Theme.textCaption - 2
                                        font.weight: parent.isToday ? Theme.weightBold : Theme.weightRegular
                                    }
                                    // event marker dot below number
                                    Rectangle {
                                        visible: parent.hasEvent && !parent.isToday
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 1
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 3; height: 3; radius: 1.5
                                        color: Theme.accent
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
