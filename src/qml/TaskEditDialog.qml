import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Dialog {
    id: dialog
    modal: true
    width: 440
    padding: 0
    title: editingId > 0 ? "Edit task" : "New task"

    property int editingId: 0
    signal saved(int id, string text, date due, bool hasDue)
    signal removed(int id)

    function openFor(id, text, due, hasDue) {
        editingId = id;
        textField.text = text;
        if (hasDue) {
            dueField.text = Qt.formatDateTime(due, "yyyy-MM-dd HH:mm");
        } else {
            dueField.text = "";
        }
        open();
        Qt.callLater(function() {
            textField.forceActiveFocus();
            textField.selectAll();
        });
    }

    function _parse(s) {
        var m = (s || "").match(/^\s*(\d{4})-(\d{1,2})-(\d{1,2})[\sT]+(\d{1,2}):(\d{1,2})\s*$/);
        if (!m) return null;
        var y = +m[1], mo = +m[2], d = +m[3], h = +m[4], mi = +m[5];
        if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59) return null;
        var dt = new Date(y, mo - 1, d, h, mi, 0, 0);
        return isNaN(dt.getTime()) ? null : dt;
    }

    function _dueValid() {
        return dueField.text === "" || _parse(dueField.text) !== null;
    }

    function _commit() {
        if (!saveBtn.enabled) return;
        var hasDue = dueField.text !== "";
        var d = hasDue ? _parse(dueField.text) : new Date();
        saved(editingId, textField.text.trim(), d, hasDue);
        close();
    }

    background: Rectangle {
        color: Material.theme === Material.Dark ? "#1e1e2e" : "#ffffff"
        radius: 16
        border.color: Material.theme === Material.Dark ? "#313244" : "#dce0e8"
        border.width: 1
    }

    header: Item {
        implicitHeight: 56
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            text: dialog.title
            font.pixelSize: 18
            font.weight: Font.DemiBold
            color: Material.foreground
        }
    }

    contentItem: ColumnLayout {
        spacing: 14

        TextField {
            id: textField
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            placeholderText: "What"
            font.pixelSize: 16
            Keys.onReturnPressed: dialog._commit()
            Keys.onEnterPressed: dialog._commit()
        }

        TextField {
            id: dueField
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            placeholderText: "Due (yyyy-MM-dd HH:mm) — blank for no due"
            font.family: "monospace"
            color: dialog._dueValid() ? Material.foreground : "#f38ba8"
            Keys.onReturnPressed: dialog._commit()
            Keys.onEnterPressed: dialog._commit()
        }

        Item { Layout.preferredHeight: 4 }
    }

    footer: Item {
        implicitHeight: 60
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 8

            Button {
                text: "Delete"
                visible: dialog.editingId > 0
                flat: true
                Material.foreground: "#f38ba8"
                onClicked: {
                    dialog.removed(dialog.editingId);
                    dialog.close();
                }
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Cancel"
                flat: true
                onClicked: dialog.close()
            }
            Button {
                id: saveBtn
                text: "Save"
                highlighted: true
                enabled: textField.text.trim() !== "" && dialog._dueValid()
                onClicked: dialog._commit()
            }
        }
    }
}
