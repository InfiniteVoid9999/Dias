import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Dias

Item {
    id: root

    signal addRequested()
    signal editRequested(int id, string taskText, date due, bool hasDue)

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.sp5
        anchors.rightMargin: Theme.sp5
        anchors.topMargin: Theme.sp6
        anchors.bottomMargin: Theme.sp5
        spacing: Theme.sp3

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
                            onClicked: root.editRequested(rowItem.id, rowItem.text, rowItem.due, rowItem.hasDue)
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
