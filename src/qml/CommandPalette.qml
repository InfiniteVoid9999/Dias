import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Dias

// Universal action launcher. Ctrl+K opens it. Type to filter, arrow keys
// or hover to highlight, Enter to run.
Popup {
    id: popup
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: 580
    padding: 0

    // Each action: { glyph, title, hint, run() }
    property var actions: []
    property var _filtered: actions
    property int _selected: 0

    function openPalette() {
        x = (parent.width - width) / 2;
        y = 120;
        queryField.text = "";
        _filtered = actions;
        _selected = 0;
        open();
        queryField.forceActiveFocus();
    }

    function _filter(q) {
        if (!q || q.length === 0) { _filtered = actions; _selected = 0; return; }
        var ql = q.toLowerCase();
        var hit = [];
        for (var i = 0; i < actions.length; i++) {
            var a = actions[i];
            var hay = (a.title + " " + (a.hint || "")).toLowerCase();
            // simple subsequence match — every char of query must appear in order in hay
            var pos = 0, ok = true;
            for (var j = 0; j < ql.length; j++) {
                var c = ql[j];
                if (c === " ") continue;
                var idx = hay.indexOf(c, pos);
                if (idx < 0) { ok = false; break; }
                pos = idx + 1;
            }
            if (ok) hit.push(a);
        }
        _filtered = hit;
        _selected = 0;
    }

    function _runSelected() {
        if (_selected < 0 || _selected >= _filtered.length) return;
        var a = _filtered[_selected];
        popup.close();
        if (a && a.run) a.run();
    }

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusCard
        border.color: Theme.border
        border.width: 1
    }

    contentItem: ColumnLayout {
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.sp3
            spacing: Theme.sp2

            Text {
                text: "terminal"
                font.family: Theme.iconFont
                font.pixelSize: 20
                color: Theme.accent
            }
            TextField {
                id: queryField
                Layout.fillWidth: true
                placeholderText: "Run a command…"
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textInput
                Material.accent: Theme.accent
                color: Theme.fg
                background: null
                onTextChanged: popup._filter(text)
                Keys.onEscapePressed: popup.close()
                Keys.onReturnPressed: popup._runSelected()
                Keys.onDownPressed: popup._selected = Math.min(popup._filtered.length - 1, popup._selected + 1)
                Keys.onUpPressed:   popup._selected = Math.max(0, popup._selected - 1)
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(420, Math.max(56, popup._filtered.length * 44))
            model: popup._filtered
            clip: true
            ScrollBar.vertical: ScrollBar {}
            currentIndex: popup._selected
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Item {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 44

                Rectangle {
                    anchors.fill: parent
                    color: parent.index === popup._selected ? Qt.alpha(Theme.accent, 0.18)
                          : rowHov.hovered ? Theme.hoverTint
                          : "transparent"
                    HoverHandler {
                        id: rowHov
                        onHoveredChanged: if (hovered) popup._selected = parent.parent.index
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { popup._selected = parent.parent.index; popup._runSelected(); }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.sp4
                    anchors.rightMargin: Theme.sp4
                    spacing: Theme.sp3

                    Text {
                        text: modelData.glyph || "play_arrow"
                        font.family: Theme.iconFont
                        font.pixelSize: 18
                        color: Theme.fgMuted
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: Theme.fg
                        font.family: Theme.sansStack[0]
                        font.pixelSize: Theme.textBody
                        elide: Text.ElideRight
                    }
                    Text {
                        text: modelData.hint || ""
                        color: Theme.fgSubtle
                        font.family: Theme.monoStack[0]
                        font.pixelSize: Theme.textCaption
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: parent.count === 0
                text: "no matches"
                color: Theme.fgSubtle
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textBody
            }
        }
    }
}
