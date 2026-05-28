import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Dias

// Natural-language quick add. Single text field that parses phrases like:
//
//   "lunch with john tomorrow at 1pm 1h"
//   "dentist friday 10:30am"
//   "vacation next week"               (all-day, defaults to today otherwise)
//   "team standup mon 9am 30m"
//
// Strips the recognized date/time/duration tokens from the input and uses
// what's left as the event title. Always picks something usable — falls
// back to "today at next hour, 1h" if nothing matched.
Popup {
    id: popup
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: 600
    padding: 0

    signal accepted(string title, date start, date end, bool allDay)

    function openQuick() {
        x = (parent.width - width) / 2;
        y = 96;
        input.text = "";
        previewLabel.text = "";
        open();
        input.forceActiveFocus();
    }

    function parse(raw) {
        var s = (raw || "").trim();
        if (!s) return null;
        var now = new Date();
        var lower = s.toLowerCase();

        var date = null;
        var time = null;
        var durationSec = 0;
        var allDay = false;

        function strip(re) { lower = lower.replace(re, " "); }

        function weekdayOffset(name, forceNext) {
            var map = { sun:0, mon:1, tue:2, wed:3, thu:4, fri:5, sat:6 };
            var idx = map[name.slice(0,3)];
            var diff = (idx - now.getDay() + 7) % 7;
            if (diff === 0 || (forceNext && diff < 7)) diff += 7;
            if (forceNext && diff === 7 && now.getDay() === idx) {
                // already on this weekday and "next" specified → skip a full week
            }
            return diff;
        }

        function mkDate(off) {
            var d = new Date(now);
            d.setDate(d.getDate() + off);
            d.setHours(0, 0, 0, 0);
            return d;
        }

        // ---- date phrases ----
        var dateMatchers = [
            { re: /\btoday\b/,                                  fn: () => mkDate(0) },
            { re: /\btonight\b/,                                fn: () => mkDate(0) },
            { re: /\btomorrow\b/,                               fn: () => mkDate(1) },
            { re: /\byesterday\b/,                              fn: () => mkDate(-1) },
            { re: /\bin (\d+) days?\b/,                         fn: m => mkDate(parseInt(m[1])) },
            { re: /\bin (\d+) weeks?\b/,                        fn: m => mkDate(parseInt(m[1]) * 7) },
            { re: /\bnext week\b/,                              fn: () => { var d = mkDate(0); d.setDate(d.getDate() + (8 - d.getDay()) % 7 + 7); return d; } },
            { re: /\bnext (mon|tue|wed|thu|fri|sat|sun)\w*\b/,  fn: m => mkDate(weekdayOffset(m[1], true)) },
            { re: /\b(mon|tue|wed|thu|fri|sat|sun)\w*\b/,       fn: m => mkDate(weekdayOffset(m[1], false)) },
            { re: /\b(\d{4})-(\d{1,2})-(\d{1,2})\b/,            fn: m => new Date(+m[1], +m[2]-1, +m[3]) },
        ];
        for (var i = 0; i < dateMatchers.length; i++) {
            var dm = dateMatchers[i].re.exec(lower);
            if (dm) { date = dateMatchers[i].fn(dm); strip(dateMatchers[i].re); break; }
        }

        // ---- time phrases ----
        function parseAmPm(h, mm, suffix) {
            var hour = parseInt(h);
            var min  = parseInt(mm) || 0;
            if (suffix === "pm" && hour < 12) hour += 12;
            if (suffix === "am" && hour === 12) hour = 0;
            return { hour: hour, min: min };
        }
        var timeMatchers = [
            { re: /\bat (\d{1,2}):(\d{2})\s?(am|pm)?\b/, fn: m => parseAmPm(m[1], m[2], m[3]) },
            { re: /\bat (\d{1,2})\s?(am|pm)\b/,          fn: m => parseAmPm(m[1], 0, m[2]) },
            { re: /\b(\d{1,2}):(\d{2})\s?(am|pm)?\b/,    fn: m => parseAmPm(m[1], m[2], m[3]) },
            { re: /\b(\d{1,2})\s?(am|pm)\b/,             fn: m => parseAmPm(m[1], 0, m[2]) },
            { re: /\bnoon\b/,                             fn: () => ({ hour:12, min:0 }) },
            { re: /\bmidnight\b/,                         fn: () => ({ hour:0,  min:0 }) },
        ];
        for (var j = 0; j < timeMatchers.length; j++) {
            var tm = timeMatchers[j].re.exec(lower);
            if (tm) { time = timeMatchers[j].fn(tm); strip(timeMatchers[j].re); break; }
        }

        // ---- duration ----
        var compound = /\b(\d+)h\s*(\d+)m?\b/.exec(lower);
        if (compound) {
            durationSec = (parseInt(compound[1]) * 60 + parseInt(compound[2])) * 60;
            strip(/\b(\d+)h\s*(\d+)m?\b/);
        } else {
            var dur = /\b(?:for )?(\d+)\s?(h|hr|hrs|hour|hours|m|min|mins|minute|minutes)\b/.exec(lower);
            if (dur) {
                var n = parseInt(dur[1]);
                var unit = dur[2];
                durationSec = unit.startsWith("h") ? n * 3600 : n * 60;
                strip(/\b(?:for )?(\d+)\s?(h|hr|hrs|hour|hours|m|min|mins|minute|minutes)\b/);
            }
        }

        if (/\ball ?day\b/.test(lower)) { allDay = true; strip(/\ball ?day\b/); }
        if (!time) allDay = true;  // no time mentioned → treat as all-day

        // ---- title = what's left ----
        var title = lower
            .replace(/\b(at|on|for|the|a|an)\b/g, "")
            .replace(/\s+/g, " ")
            .trim();
        if (title.length === 0) title = "(untitled)";
        // restore reasonable case from the original string by taking original
        // tokens whose lower form is in our cleaned title
        var originalWords = s.split(/\s+/);
        var titleWordsSet = new Set(title.split(/\s+/));
        var pretty = originalWords.filter(w => titleWordsSet.has(w.toLowerCase())).join(" ");
        if (pretty.length > 0) title = pretty;

        // ---- build start/end ----
        var d0 = date || mkDate(0);
        var start = new Date(d0);
        if (time) start.setHours(time.hour, time.min, 0, 0);
        else      start.setHours(0, 0, 0, 0);
        var end;
        if (allDay) {
            end = new Date(start);
            end.setHours(23, 59, 0, 0);
        } else if (durationSec > 0) {
            end = new Date(start.getTime() + durationSec * 1000);
        } else {
            end = new Date(start.getTime() + 3600 * 1000);
        }
        return { title: title, start: start, end: end, allDay: allDay };
    }

    function _renderPreview(text) {
        var p = parse(text);
        if (!p) { previewLabel.text = ""; return; }
        var when = p.allDay
            ? Qt.formatDate(p.start, "ddd, d MMM yyyy") + " — all day"
            : Qt.formatDateTime(p.start, "ddd, d MMM yyyy · HH:mm")
              + " → " + Qt.formatTime(p.end, "HH:mm");
        previewLabel.text = '"' + p.title + '"  •  ' + when;
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
                text: "bolt"
                font.family: Theme.iconFont
                font.pixelSize: 20
                color: Theme.accent
            }
            TextField {
                id: input
                Layout.fillWidth: true
                placeholderText: 'e.g. "lunch with john tomorrow at 1pm 1h"'
                font.family: Theme.sansStack[0]
                font.pixelSize: Theme.textInput
                Material.accent: Theme.accent
                color: Theme.fg
                background: null
                onTextChanged: popup._renderPreview(text)
                Keys.onEscapePressed: popup.close()
                Keys.onReturnPressed: {
                    var p = popup.parse(text);
                    if (!p) { popup.close(); return; }
                    popup.accepted(p.title, p.start, p.end, p.allDay);
                    popup.close();
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.divider
            visible: previewLabel.text !== ""
        }

        Text {
            id: previewLabel
            Layout.fillWidth: true
            Layout.margins: Theme.sp3
            text: ""
            visible: text !== ""
            color: Theme.fgMuted
            font.family: Theme.sansStack[0]
            font.pixelSize: Theme.textBody
            elide: Text.ElideRight
        }
    }
}
