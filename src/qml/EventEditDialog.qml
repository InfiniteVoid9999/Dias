import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Dias

Dialog {
    id: dialog
    modal: true
    width: 480
    padding: 0
    title: editingId > 0 ? "Edit event" : "New event"

    property int editingId: 0
    signal saved(int id, string evTitle, date start, date end, string category)
    signal removed(int id)

    function openFor(id, evTitle, start, end, category) {
        editingId = id;
        titleField.text = evTitle;
        startField.text = Qt.formatDateTime(start, "yyyy-MM-dd HH:mm");
        endField.text   = Qt.formatDateTime(end,   "yyyy-MM-dd HH:mm");
        categoryField.text = category;
        open();
        Qt.callLater(function() {
            titleField.forceActiveFocus();
            titleField.selectAll();
        });
    }

    function _parse(s) {
        var m = (s || "").match(/^\s*(\d{4})-(\d{1,2})-(\d{1,2})[\sT]+(\d{1,2}):(\d{1,2})\s*$/);
        if (!m) return null;
        var y  = +m[1], mo = +m[2], d  = +m[3], h  = +m[4], mi = +m[5];
        if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59) return null;
        var dt = new Date(y, mo - 1, d, h, mi, 0, 0);
        return isNaN(dt.getTime()) ? null : dt;
    }

    function _commit() {
        if (!saveBtn.enabled) return;
        var s = _parse(startField.text);
        var e = _parse(endField.text);
        if (e <= s) e = new Date(s.getTime() + 3600000);
        saved(editingId, titleField.text.trim(), s, e, categoryField.text.trim());
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
            id: titleField
            Layout.fillWidth: true
            Layout.leftMargin: Theme.sp6
            Layout.rightMargin: Theme.sp6
            placeholderText: "Title"
            font.family: Theme.sansStack[0]
            font.pixelSize: Theme.textInput
            Material.accent: Theme.accent
            Material.foreground: Theme.fg
            color: Theme.fg
            Keys.onReturnPressed: dialog._commit()
            Keys.onEnterPressed: dialog._commit()
        }

        RowLayout {
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
                property bool dateValid: dialog._parse(text) !== null
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
                property bool dateValid: dialog._parse(text) !== null
                color: text === "" || dateValid ? Theme.fg : Theme.error
                Keys.onReturnPressed: dialog._commit()
                Keys.onEnterPressed: dialog._commit()
            }
        }

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
                enabled: titleField.text.trim() !== "" && startField.dateValid && endField.dateValid
                onClicked: dialog._commit()
            }
        }
    }
}
