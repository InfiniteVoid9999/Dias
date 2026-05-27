import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

Dialog {
    id: dialog
    modal: true
    width: 460
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
        var y  = +m[1], mo = +m[2], d  = +m[3];
        var h  = +m[4], mi = +m[5];
        if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59) return null;
        var dt = new Date(y, mo - 1, d, h, mi, 0, 0);
        if (isNaN(dt.getTime())) return null;
        return dt;
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
            id: titleField
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            placeholderText: "Title"
            font.pixelSize: 16
            Keys.onReturnPressed: dialog._commit()
            Keys.onEnterPressed: dialog._commit()
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            spacing: 8

            TextField {
                id: startField
                Layout.fillWidth: true
                placeholderText: "yyyy-MM-dd HH:mm"
                font.family: "monospace"
                property bool dateValid: dialog._parse(text) !== null
                color: text === "" || dateValid ? Material.foreground : "#f38ba8"
                Keys.onReturnPressed: dialog._commit()
                Keys.onEnterPressed: dialog._commit()
            }
            Text {
                text: "→"
                color: Material.foreground
                opacity: 0.45
            }
            TextField {
                id: endField
                Layout.fillWidth: true
                placeholderText: "yyyy-MM-dd HH:mm"
                font.family: "monospace"
                property bool dateValid: dialog._parse(text) !== null
                color: text === "" || dateValid ? Material.foreground : "#f38ba8"
                Keys.onReturnPressed: dialog._commit()
                Keys.onEnterPressed: dialog._commit()
            }
        }

        TextField {
            id: categoryField
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            placeholderText: "Category (optional)"
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
                enabled: titleField.text.trim() !== "" && startField.dateValid && endField.dateValid
                onClicked: dialog._commit()
            }
        }
    }
}
