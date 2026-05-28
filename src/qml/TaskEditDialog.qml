import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Dias

Dialog {
    id: dialog
    modal: true
    width: 460
    padding: 0
    title: editingId > 0 ? "Edit task" : "New task"

    property int editingId: 0
    signal saved(int id, string text, date due, bool hasDue)
    signal removed(int id)

    function openFor(id, text, due, hasDue) {
        editingId = id;
        textField.text = text;
        dueField.text = hasDue ? Qt.formatDateTime(due, "yyyy-MM-dd HH:mm") : "";
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

    function _dueValid() { return dueField.text === "" || _parse(dueField.text) !== null; }

    function _commit() {
        if (!saveBtn.enabled) return;
        var hasDue = dueField.text !== "";
        var d = hasDue ? _parse(dueField.text) : new Date();
        saved(editingId, textField.text.trim(), d, hasDue);
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

    contentItem: ColumnLayout {
        spacing: Theme.sp3

        TextField {
            id: textField
            Layout.fillWidth: true
            Layout.leftMargin: Theme.sp6
            Layout.rightMargin: Theme.sp6
            placeholderText: "What"
            font.family: Theme.sansStack[0]
            font.pixelSize: Theme.textInput
            Material.accent: Theme.accent
            color: Theme.fg
            Keys.onReturnPressed: dialog._commit()
            Keys.onEnterPressed: dialog._commit()
        }

        TextField {
            id: dueField
            Layout.fillWidth: true
            Layout.leftMargin: Theme.sp6
            Layout.rightMargin: Theme.sp6
            placeholderText: "Due (yyyy-MM-dd HH:mm) — blank for no due"
            font.family: Theme.monoStack[0]
            font.pixelSize: Theme.textBody
            Material.accent: Theme.accent
            color: dialog._dueValid() ? Theme.fg : Theme.error
            Keys.onReturnPressed: dialog._commit()
            Keys.onEnterPressed: dialog._commit()
        }

        Item { Layout.preferredHeight: Theme.sp1 }
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
                enabled: textField.text.trim() !== "" && dialog._dueValid()
                onClicked: dialog._commit()
            }
        }
    }
}
