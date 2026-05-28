import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Dias

Item {
    id: root

    signal addRequested()
    signal editRequested(int id, string taskText, date due, bool hasDue, int priority)

    readonly property var _priorityColors: [
        "transparent",
        Theme.success,
        Theme.warning,
        Theme.error
    ]

    // -------- calendar list (top section) --------
    Dialog {
        id: addCalDialog
        modal: true
        anchors.centerIn: parent
        width: 360
        padding: 0
        title: "New calendar"
        background: Rectangle {
            color: Theme.surface; radius: Theme.radiusCard
            border.color: Theme.border; border.width: 1
        }
        header: Item {
            implicitHeight: 48
            Text {
                anchors.left: parent.left; anchors.leftMargin: Theme.sp4
                anchors.verticalCenter: parent.verticalCenter
                text: addCalDialog.title
                color: Theme.fg; font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textBody; font.weight: Theme.weightBold
            }
        }
        property string chosenColor: "#89b4fa"
        readonly property var swatch: ["#89b4fa","#a6e3a1","#cba6f7","#f5c2e7","#fab387","#94e2d5","#f9e2af","#89dceb","#f38ba8"]

        contentItem: ColumnLayout {
            spacing: Theme.sp2
            TextField {
                id: calNameField
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp4; Layout.rightMargin: Theme.sp4
                placeholderText: "Calendar name"
                font.family: Theme.sansStack[0]
                Material.accent: Theme.accent
                color: Theme.fg
            }
            Flow {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.sp4; Layout.rightMargin: Theme.sp4
                spacing: 6
                Repeater {
                    model: addCalDialog.swatch
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: modelData
                        border.color: addCalDialog.chosenColor === modelData ? Theme.fg : "transparent"
                        border.width: 2
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: addCalDialog.chosenColor = modelData
                        }
                    }
                }
            }
            Item { Layout.preferredHeight: Theme.sp1 }
        }
        footer: Item {
            implicitHeight: 56
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp3; anchors.rightMargin: Theme.sp3
                Item { Layout.fillWidth: true }
                Button { text: "Cancel"; flat: true; onClicked: addCalDialog.close() }
                Button {
                    text: "Create"; highlighted: true
                    Material.accent: Theme.accent; Material.foreground: Theme.onAccent
                    enabled: calNameField.text.trim() !== ""
                    onClicked: {
                        CalendarModel.createCalendar(calNameField.text.trim(), addCalDialog.chosenColor);
                        calNameField.text = "";
                        addCalDialog.close();
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.sp5
        anchors.rightMargin: Theme.sp5
        anchors.topMargin: Theme.sp6
        anchors.bottomMargin: Theme.sp5
        spacing: Theme.sp3

        // calendars section
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2

            Text {
                text: "Calendars"
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textTitle
                font.weight: Theme.weightBold
                color: Theme.fg
            }
            Item { Layout.fillWidth: true }
            ToolButton {
                text: "add"
                font.family: Theme.iconFont
                font.pixelSize: 20
                Material.foreground: Theme.fgMuted
                ToolTip.visible: hovered; ToolTip.delay: 600; ToolTip.text: "New calendar"
                onClicked: addCalDialog.open()
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: CalendarModel
                delegate: Item {
                    id: calRow
                    required property int id
                    required property string name
                    required property string color
                    required property bool shown
                    width: parent.width
                    height: 30

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusRow
                        color: calHover.hovered ? Theme.hoverTint : "transparent"
                        HoverHandler { id: calHover }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sp2
                        anchors.rightMargin: Theme.sp2
                        spacing: Theme.sp2

                        Rectangle {
                            implicitWidth: 14; implicitHeight: 14; radius: 7
                            color: calRow.shown ? calRow.color : "transparent"
                            border.color: calRow.color
                            border.width: 2
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: CalendarModel.setVisible(calRow.id, !calRow.shown)
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: calRow.name
                            color: calRow.shown ? Theme.fg : Theme.fgSubtle
                            font.family: Theme.sansStack[0]
                            font.pixelSize: Theme.textBody
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.divider
        }

        // todo section
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2

            Text {
                text: "To Do"
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textTitle
                font.weight: Theme.weightBold
                color: Theme.fg
            }
            Text {
                visible: list.count > 0
                text: list.count + ""
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textCaption
                font.weight: Theme.weightMedium
                color: Theme.fgSubtle
            }
            Item { Layout.fillWidth: true }
            ToolButton {
                text: "add"
                font.family: Theme.iconFont
                font.pixelSize: 22
                Material.foreground: Theme.fgMuted
                ToolTip.visible: hovered
                ToolTip.delay: 600
                ToolTip.text: "Add task"
                onClicked: root.addRequested()
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.sp1
            model: TaskModel
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {}

            delegate: Item {
                id: rowItem
                width: list.width
                height: 40

                required property int id
                required property string text
                required property var due
                required property bool hasDue
                required property bool done
                required property int priority

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusRow
                    color: hover.hovered ? Theme.hoverTint : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    HoverHandler { id: hover }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.sp1
                    anchors.rightMargin: Theme.sp2
                    spacing: Theme.sp2

                    // priority dot (4px circle) — invisible if priority=0
                    Rectangle {
                        Layout.preferredWidth: 4
                        Layout.preferredHeight: 16
                        radius: 2
                        color: root._priorityColors[Math.max(0, Math.min(3, rowItem.priority))]
                    }

                    CheckBox {
                        checked: rowItem.done
                        Material.accent: Theme.accent
                        onToggled: TaskModel.setDone(rowItem.id, checked)
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        RowLayout {
                            anchors.fill: parent
                            spacing: Theme.sp2

                            Text {
                                Layout.fillWidth: true
                                text: rowItem.text
                                font.family: Theme.sansStack[0]
                                font.pixelSize: Theme.textBody
                                font.weight: Theme.weightRegular
                                color: Theme.fg
                                opacity: rowItem.done ? Theme.doneOpacity : 1.0
                                font.strikeout: rowItem.done
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                            Rectangle {
                                visible: rowItem.hasDue
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: chipText.implicitWidth + Theme.sp3
                                implicitHeight: 20
                                radius: Theme.radiusPill
                                color: Theme.surface
                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: rowItem.hasDue ? Qt.formatDateTime(rowItem.due, "ddd HH:mm") : ""
                                    font.family: Theme.monoStack[0]
                                    font.pixelSize: Theme.textCaption
                                    color: Theme.fgMuted
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.editRequested(rowItem.id, rowItem.text, rowItem.due, rowItem.hasDue, rowItem.priority)
                        }
                    }
                }
            }

            // empty state
            Column {
                anchors.centerIn: parent
                visible: list.count === 0
                spacing: Theme.sp2

                Text {
                    text: "check_circle"
                    font.family: Theme.iconFont
                    font.pixelSize: 36
                    color: Theme.fgSubtle
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "nothing to do"
                    font.family: Theme.sansStack[0]
                    font.pixelSize: Theme.textBody
                    color: Theme.fgSubtle
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
