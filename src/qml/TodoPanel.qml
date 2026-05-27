import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Item {
    id: root

    signal addRequested()
    signal editRequested(int id, string taskText, date due, bool hasDue)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "To Do"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: Material.foreground
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "+ add"
                flat: true
                onClicked: root.addRequested()
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: TaskModel

            ScrollBar.vertical: ScrollBar {}

            delegate: Item {
                id: rowItem
                width: list.width
                height: 36

                required property int id
                required property string text
                required property var due
                required property bool hasDue
                required property bool done

                Rectangle {
                    id: bg
                    anchors.fill: parent
                    radius: 8
                    color: hover.hovered ? Qt.alpha(Material.foreground, 0.06) : "transparent"
                    HoverHandler { id: hover }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    CheckBox {
                        checked: rowItem.done
                        onToggled: TaskModel.setDone(rowItem.id, checked)
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: rowItem.text
                                font.pixelSize: 13
                                color: Material.foreground
                                opacity: rowItem.done ? 0.45 : 1.0
                                font.strikeout: rowItem.done
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                visible: rowItem.hasDue
                                text: Qt.formatDateTime(rowItem.due, "ddd HH:mm")
                                font.pixelSize: 11
                                font.family: "monospace"
                                color: Material.foreground
                                opacity: 0.55
                                verticalAlignment: Text.AlignVCenter
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

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "no tasks\n+ add one"
                color: Material.foreground
                opacity: 0.35
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
