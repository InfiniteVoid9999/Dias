import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Dias

// Compact RRULE editor used inside EventEditDialog.
// MVP scope: FREQ (none/daily/weekly/monthly/yearly), INTERVAL, BYDAY (weekly),
// COUNT. Matches what RRule.h can expand for display.
Item {
    id: root
    implicitHeight: column.implicitHeight

    property string rrule: ""

    function _parseInto() {
        var defaults = { freq: "NONE", interval: 1, byday: [], count: 0 };
        if (!rrule || rrule.length === 0) return defaults;
        var s = rrule.replace(/^RRULE:/i, "");
        var parts = s.split(";");
        for (var i = 0; i < parts.length; i++) {
            var eq = parts[i].indexOf("=");
            if (eq < 0) continue;
            var k = parts[i].substring(0, eq).toUpperCase();
            var v = parts[i].substring(eq + 1);
            if (k === "FREQ")     defaults.freq = v.toUpperCase();
            else if (k === "INTERVAL") defaults.interval = parseInt(v) || 1;
            else if (k === "COUNT")    defaults.count = parseInt(v) || 0;
            else if (k === "BYDAY")    defaults.byday = v.split(",");
        }
        return defaults;
    }

    function _buildRrule() {
        if (freqCombo.currentText === "Never") return "";
        var parts = ["FREQ=" + freqCombo.currentText.toUpperCase()];
        if (intervalSpin.value > 1) parts.push("INTERVAL=" + intervalSpin.value);
        if (freqCombo.currentText === "Weekly") {
            var sel = [];
            for (var i = 0; i < 7; i++) {
                if (dayChips.itemAt(i).selected) {
                    sel.push(["MO","TU","WE","TH","FR","SA","SU"][i]);
                }
            }
            if (sel.length > 0) parts.push("BYDAY=" + sel.join(","));
        }
        if (countSpin.value > 0) parts.push("COUNT=" + countSpin.value);
        return parts.join(";");
    }

    onRruleChanged: {
        var p = _parseInto();
        var idx = ({ "NONE":0, "DAILY":1, "WEEKLY":2, "MONTHLY":3, "YEARLY":4 })[p.freq] || 0;
        if (freqCombo.currentIndex !== idx) freqCombo.currentIndex = idx;
        if (intervalSpin.value !== p.interval) intervalSpin.value = p.interval;
        if (countSpin.value !== p.count) countSpin.value = p.count;
        for (var i = 0; i < 7; i++) {
            var code = ["MO","TU","WE","TH","FR","SA","SU"][i];
            dayChips.itemAt(i).selected = p.byday.indexOf(code) >= 0;
        }
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.sp2

        RowLayout {
            spacing: Theme.sp2
            Text {
                text: "Repeats"
                color: Theme.fgMuted
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textBody
                Layout.preferredWidth: 80
            }
            ComboBox {
                id: freqCombo
                Layout.fillWidth: true
                model: ["Never", "Daily", "Weekly", "Monthly", "Yearly"]
                onCurrentTextChanged: root.rrule = root._buildRrule()
            }
        }

        RowLayout {
            visible: freqCombo.currentText !== "Never"
            spacing: Theme.sp2
            Text {
                text: "Every"
                color: Theme.fgMuted
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textBody
                Layout.preferredWidth: 80
            }
            SpinBox {
                id: intervalSpin
                from: 1; to: 99
                value: 1
                onValueModified: root.rrule = root._buildRrule()
            }
            Text {
                text: {
                    var f = freqCombo.currentText.toLowerCase();
                    var unit = f === "daily" ? "day" : f === "weekly" ? "week"
                             : f === "monthly" ? "month" : "year";
                    return intervalSpin.value === 1 ? unit : unit + "s";
                }
                color: Theme.fgMuted
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textBody
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            visible: freqCombo.currentText === "Weekly"
            spacing: Theme.sp1
            Text {
                text: "On"
                color: Theme.fgMuted
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textBody
                Layout.preferredWidth: 80
            }
            Repeater {
                id: dayChips
                model: ["M","T","W","T","F","S","S"]
                delegate: Rectangle {
                    property bool selected: false
                    width: 30; height: 30
                    radius: Theme.radiusPill
                    color: selected ? Theme.accent : Theme.surface
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: parent.selected ? Theme.onAccent : Theme.fgMuted
                        font.family: Theme.sansStack[0]
                        font.pixelSize: Theme.textCaption
                        font.weight: Theme.weightMedium
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            parent.selected = !parent.selected;
                            root.rrule = root._buildRrule();
                        }
                    }
                }
            }
        }

        RowLayout {
            visible: freqCombo.currentText !== "Never"
            spacing: Theme.sp2
            Text {
                text: "Stop after"
                color: Theme.fgMuted
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textBody
                Layout.preferredWidth: 80
            }
            SpinBox {
                id: countSpin
                from: 0; to: 999
                value: 0
                onValueModified: root.rrule = root._buildRrule()
            }
            Text {
                text: countSpin.value === 0 ? "never" : (countSpin.value + " occurrences")
                color: Theme.fgMuted
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textBody
            }
            Item { Layout.fillWidth: true }
        }
    }
}
