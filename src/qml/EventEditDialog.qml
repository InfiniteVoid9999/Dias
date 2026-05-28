import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Dias

Dialog {
    id: dialog
    modal: true
    width: 540
    padding: 0
    title: editingId > 0 ? "Edit event" : "New event"

    property int editingId: 0
    property int evCalendarId: 1
    signal saved(int id, string evTitle, date start, date end, string category,
                 string rrule, bool allDay, string notes, string location, int reminderMinutes,
                 int calendarId)
    signal removed(int id)

    function openFor(args) {
        editingId = args.id || 0;
        titleField.text = args.title || "";
        startField.text = args.start ? Qt.formatDateTime(args.start, "yyyy-MM-dd HH:mm") : "";
        endField.text   = args.end   ? Qt.formatDateTime(args.end,   "yyyy-MM-dd HH:mm") : "";
        allDayField.text = args.start ? Qt.formatDate(args.start, "yyyy-MM-dd") : "";
        categoryField.text = args.category || "";
        notesArea.text = args.notes || "";
        locationField.text = args.location || "";
        allDayToggle.checked = args.allDay || false;
        rruleEditor.rrule = args.rrule || "";
        evCalendarId = args.calendarId || 1;
        // map reminder minutes back to combo index
        var r = args.reminderMinutes || 0;
        var idx = ({ 0:0, 5:1, 15:2, 30:3, 60:4, 1440:5 })[r];
        reminderCombo.currentIndex = (idx === undefined) ? 0 : idx;
        open();
        Qt.callLater(function() {
            titleField.forceActiveFocus();
            titleField.selectAll();
        });
    }

    function _parseDateTime(s) {
        var m = (s || "").match(/^\s*(\d{4})-(\d{1,2})-(\d{1,2})[\sT]+(\d{1,2}):(\d{1,2})\s*$/);
        if (!m) return null;
        var y = +m[1], mo = +m[2], d = +m[3], h = +m[4], mi = +m[5];
        if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59) return null;
        var dt = new Date(y, mo - 1, d, h, mi, 0, 0);
        return isNaN(dt.getTime()) ? null : dt;
    }
    function _parseDate(s) {
        var m = (s || "").match(/^\s*(\d{4})-(\d{1,2})-(\d{1,2})\s*$/);
        if (!m) return null;
        var dt = new Date(+m[1], +m[2] - 1, +m[3]);
        return isNaN(dt.getTime()) ? null : dt;
    }

    readonly property var _reminderValues: [0, 5, 15, 30, 60, 1440]
    readonly property var _reminderLabels: ["None", "5 min before", "15 min before", "30 min before", "1 hour before", "1 day before"]

    function _commit() {
        if (!saveBtn.enabled) return;
        var s, e;
        if (allDayToggle.checked) {
            var d = _parseDate(allDayField.text);
            if (!d) return;
            s = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0);
            e = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 0);
        } else {
            s = _parseDateTime(startField.text);
            e = _parseDateTime(endField.text);
            if (e <= s) e = new Date(s.getTime() + 3600000);
        }
        saved(editingId, titleField.text.trim(), s, e,
              categoryField.text.trim(), rruleEditor.rrule,
              allDayToggle.checked, notesArea.text.trim(),
              locationField.text.trim(), _reminderValues[reminderCombo.currentIndex],
              evCalendarId);
        close();
    }

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusCard
        border.color: Theme.border
        border.width: 1
    }

    header: Item {
        implicitHeight: 64
        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.sp6
            anchors.verticalCenter: parent.verticalCenter
            text: dialog.title
            font.family: Theme.sansStack[0]
            font.pixelSize: Theme.textTitle
            font.weight: Theme.weightBold
            color: Theme.fg
        }
    }

    contentItem: ScrollView {
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: dialog.width
            spacing: Theme.sp3

            TextField {
                id: titleField
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
                placeholderText: "Title"
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textInput
                Material.accent: Theme.accent
                color: Theme.fg
                Keys.onReturnPressed: dialog._commit()
                Keys.onEnterPressed: dialog._commit()
            }

            // all-day toggle row
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
                spacing: Theme.sp2

                Switch {
                    id: allDayToggle
                    Material.accent: Theme.accent
                }
                Text {
                    text: "All day"
                    color: Theme.fgMuted
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textBody
                }
                Item { Layout.fillWidth: true }
            }

            // time fields when not all-day
            RowLayout {
                visible: !allDayToggle.checked
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
                spacing: Theme.sp2

                TextField {
                    id: startField
                    Layout.fillWidth: true
                    placeholderText: "yyyy-MM-dd HH:mm"
                    font.family: Theme.monoStack[0]
                    font.pixelSize: Theme.textBody
                    Material.accent: Theme.accent
                    property bool dateValid: dialog._parseDateTime(text) !== null
                    color: text === "" || dateValid ? Theme.fg : Theme.error
                    Keys.onReturnPressed: dialog._commit()
                    Keys.onEnterPressed: dialog._commit()
                }
                Text {
                    text: "arrow_forward"
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: Theme.fgSubtle
                }
                TextField {
                    id: endField
                    Layout.fillWidth: true
                    placeholderText: "yyyy-MM-dd HH:mm"
                    font.family: Theme.monoStack[0]
                    font.pixelSize: Theme.textBody
                    Material.accent: Theme.accent
                    property bool dateValid: dialog._parseDateTime(text) !== null
                    color: text === "" || dateValid ? Theme.fg : Theme.error
                    Keys.onReturnPressed: dialog._commit()
                    Keys.onEnterPressed: dialog._commit()
                }
            }

            // single date field when all-day
            TextField {
                id: allDayField
                visible: allDayToggle.checked
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
                placeholderText: "yyyy-MM-dd"
                font.family: Theme.monoStack[0]
                font.pixelSize: Theme.textBody
                Material.accent: Theme.accent
                property bool dateValid: dialog._parseDate(text) !== null
                color: text === "" || dateValid ? Theme.fg : Theme.error
                Keys.onReturnPressed: dialog._commit()
                Keys.onEnterPressed: dialog._commit()
            }

            // location with icon
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
                spacing: Theme.sp2

                Text {
                    text: "location_on"
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: Theme.fgSubtle
                }
                TextField {
                    id: locationField
                    Layout.fillWidth: true
                    placeholderText: "Location"
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textBody
                    Material.accent: Theme.accent
                    color: Theme.fg
                    Keys.onReturnPressed: dialog._commit()
                    Keys.onEnterPressed: dialog._commit()
                }
            }

            // calendar picker
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
                spacing: Theme.sp2

                Text {
                    text: "calendar_today"
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: Theme.fgSubtle
                }
                Text {
                    text: "Calendar"
                    color: Theme.fgMuted
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textBody
                    Layout.preferredWidth: 70
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: CalendarModel
                        delegate: Rectangle {
                            id: calChip
                            required property int id
                            required property string name
                            required property string color
                            readonly property bool selected: dialog.evCalendarId === id

                            implicitHeight: 26
                            implicitWidth: chipText.implicitWidth + 32
                            radius: Theme.radiusPill
                            color: selected ? Qt.alpha(calChip.color, 0.30) : Theme.surfaceHigh
                            border.color: selected ? calChip.color : "transparent"
                            border.width: 1

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 10; height: 10; radius: 5
                                    color: calChip.color
                                }
                                Text {
                                    id: chipText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: calChip.name
                                    color: Theme.fg
                                    font.family: Theme.sansStack[0]
                                    font.pixelSize: Theme.textCaption + 1
                                    font.weight: Theme.weightMedium
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dialog.evCalendarId = calChip.id
                            }
                        }
                    }
                }
            }

            // category
            TextField {
                id: categoryField
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
                placeholderText: "Category (optional)"
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textBody
                Material.accent: Theme.accent
                color: Theme.fg
                Keys.onReturnPressed: dialog._commit()
                Keys.onEnterPressed: dialog._commit()
            }

            // notes textarea
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
                Layout.preferredHeight: 88
                radius: 6
                color: Theme.bg
                border.color: notesArea.activeFocus ? Theme.accent : Theme.border
                border.width: 1

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    TextArea {
                        id: notesArea
                        wrapMode: TextArea.Wrap
                        placeholderText: "Notes"
                        font.family: Theme.sansStack[0]
                        font.pixelSize: Theme.textBody
                        color: Theme.fg
                        background: null
                    }
                }
            }

            // reminder selector
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
                spacing: Theme.sp2

                Text {
                    text: "notifications"
                    font.family: Theme.iconFont
                    font.pixelSize: 18
                    color: Theme.fgSubtle
                }
                Text {
                    text: "Reminder"
                    color: Theme.fgMuted
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textBody
                    Layout.preferredWidth: 80
                }
                ComboBox {
                    id: reminderCombo
                    Layout.fillWidth: true
                    model: dialog._reminderLabels
                    Material.accent: Theme.accent
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
                Layout.preferredHeight: 1
                color: Theme.divider
            }

            RecurrenceEditor {
                id: rruleEditor
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp6
                Layout.rightMargin: Theme.sp6
            }

            Item { Layout.preferredHeight: Theme.sp2 }
        }
    }

    footer: Item {
        implicitHeight: 64
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.sp4
            anchors.rightMargin: Theme.sp4
            spacing: Theme.sp2

            Button {
                text: "Delete"
                visible: dialog.editingId > 0
                flat: true
                Material.foreground: Theme.error
                onClicked: {
                    dialog.removed(dialog.editingId);
                    dialog.close();
                }
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Cancel"
                flat: true
                Material.foreground: Theme.fgMuted
                onClicked: dialog.close()
            }
            Button {
                id: saveBtn
                text: "Save"
                highlighted: true
                Material.accent: Theme.accent
                Material.foreground: Theme.onAccent
                enabled: titleField.text.trim() !== ""
                         && (allDayToggle.checked
                             ? (allDayField.text !== "" && allDayField.dateValid)
                             : (startField.dateValid && endField.dateValid))
                onClicked: dialog._commit()
            }
        }
    }
}
