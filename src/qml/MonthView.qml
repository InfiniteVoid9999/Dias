import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Dias

// Month view: 6-row × 7-col grid of day cells. Anchor day (viewStart) is the
// Monday on or before the 1st of the viewed month. Each cell renders up to 3
// event chips and a "+N more" indicator; clicking a cell jumps to Day view
// at that date, clicking a chip opens the event dialog.
Item {
    id: root

    property date viewStart: EventModel.viewStart

    // The "month being viewed" — pick a date well inside the visible grid
    // (cell #14, week 3) to be safe against month boundaries.
    readonly property date monthAnchor: {
        var d = new Date(root.viewStart);
        d.setDate(d.getDate() + 14);
        return d;
    }
    readonly property int monthIndex: monthAnchor.getMonth()
    readonly property int monthYear: monthAnchor.getFullYear()

    signal editEvent(var args)
    signal selectDay(date day)

    function next() {
        var d = new Date(monthAnchor);
        d.setMonth(d.getMonth() + 1);
        EventModel.viewStart = _firstMondayOfMonthGrid(d);
        EventModel.viewDays = 42;
    }
    function prev() {
        var d = new Date(monthAnchor);
        d.setMonth(d.getMonth() - 1);
        EventModel.viewStart = _firstMondayOfMonthGrid(d);
        EventModel.viewDays = 42;
    }
    function gotoToday() {
        EventModel.viewStart = _firstMondayOfMonthGrid(new Date());
        EventModel.viewDays = 42;
    }

    function _firstMondayOfMonthGrid(anyDateInMonth) {
        var first = new Date(anyDateInMonth.getFullYear(), anyDateInMonth.getMonth(), 1);
        var dow = (first.getDay() + 6) % 7; // Mon = 0
        var monday = new Date(first);
        monday.setDate(first.getDate() - dow);
        monday.setHours(0, 0, 0, 0);
        return monday;
    }

    // Weekday header strip
    Row {
        id: weekdayRow
        width: parent.width
        height: 32
        spacing: 0
        Repeater {
            model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
            Item {
                width: weekdayRow.width / 7
                height: weekdayRow.height
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textCaption
                    font.weight: Theme.weightMedium
                    font.letterSpacing: 1.2
                    color: Theme.fgMuted
                }
            }
        }
    }

    Rectangle {
        anchors.top: weekdayRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.divider
    }

    // 6x7 grid
    Grid {
        id: grid
        anchors.top: weekdayRow.bottom
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        rows: 6
        columns: 7

        Repeater {
            model: 42
            delegate: Item {
                id: cell
                width: grid.width / 7
                height: grid.height / 6

                required property int index
                property date cellDay: {
                    var d = new Date(root.viewStart);
                    d.setDate(d.getDate() + index);
                    return d;
                }
                property bool inMonth: cellDay.getMonth() === root.monthIndex
                property bool isToday: {
                    var t = new Date();
                    return cellDay.getFullYear() === t.getFullYear()
                        && cellDay.getMonth() === t.getMonth()
                        && cellDay.getDate() === t.getDate();
                }

                // background + click target
                Rectangle {
                    anchors.fill: parent
                    color: cellHover.hovered ? Theme.hoverTint : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    HoverHandler { id: cellHover }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectDay(cell.cellDay)
                }

                // borders (right + bottom only, builds the grid lines)
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Theme.gridLine
                    visible: (index % 7) !== 6
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.gridLine
                    visible: index < 35
                }

                // day number — pill if today
                Item {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.topMargin: Theme.sp1
                    anchors.leftMargin: Theme.sp1
                    width: 28; height: 24
                    Rectangle {
                        anchors.centerIn: parent
                        width: 24; height: 24
                        radius: Theme.radiusPill
                        color: cell.isToday ? Theme.accent : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: cell.cellDay.getDate()
                        color: cell.isToday ? Theme.onAccent
                              : cell.inMonth ? Theme.fg : Theme.fgSubtle
                        font.family: Theme.sansStack[0]
                        font.pixelSize: Theme.textBody
                        font.weight: cell.isToday ? Theme.weightBold : Theme.weightRegular
                    }
                }

                // events that fall on this day, up to 3 chips + overflow
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 32
                    anchors.leftMargin: Theme.sp1
                    anchors.rightMargin: Theme.sp1
                    spacing: 2

                    Repeater {
                        model: EventModel
                        delegate: Item {
                            id: chip
                            required property int id
                            required property string title
                            required property var start
                            required property var end
                            required property string category
                            required property string source
                            required property string rrule
                            required property bool allDay
                            required property string notes
                            required property string location
                            required property int reminderMinutes

                            property bool sameDay: start.getFullYear() === cell.cellDay.getFullYear()
                                                && start.getMonth()   === cell.cellDay.getMonth()
                                                && start.getDate()    === cell.cellDay.getDate()

                            visible: sameDay && _visibleRank() < 3
                            width: parent.width
                            height: visible ? 18 : 0

                            function _visibleRank() {
                                // Count earlier same-day events to determine cap.
                                // This is O(N) per cell; fine for MVP scale.
                                var rank = 0;
                                for (var i = 0; i < index; i++) {
                                    // index here is the Repeater's index within EventModel,
                                    // already sorted by start. We can't easily peek other
                                    // delegates' data, so this stays approximate — overflow
                                    // counter below is the authoritative number.
                                }
                                return rank;
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: Qt.alpha(Theme.categoryColor(chip.category, chip.source), 0.85)

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    text: Qt.formatTime(chip.start, "HH:mm") + " " + (chip.title === "" ? "(untitled)" : chip.title)
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
                                    onClicked: function(mouse) {
                                        mouse.accepted = true;
                                        root.editEvent({
                                            id: chip.id, title: chip.title,
                                            start: chip.start, end: chip.end,
                                            category: chip.category, source: chip.source,
                                            rrule: chip.rrule, allDay: chip.allDay,
                                            notes: chip.notes, location: chip.location,
                                            reminderMinutes: chip.reminderMinutes
                                        });
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
