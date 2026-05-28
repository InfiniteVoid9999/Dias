pragma Singleton
import QtQuick

QtObject {
    id: theme

    // -------- mode --------
    // Bound by Main.qml from the resolved theme. All other tokens derive from this.
    property bool dark: true

    // -------- font stacks --------
    // Material 3 default → GNOME's Inter-derived → universal fallback.
    readonly property var sansStack: ["Google Sans Flex", "Adwaita Sans", "Noto Sans", "sans-serif"]
    readonly property var monoStack: ["GeistMono Nerd Font", "Noto Sans Mono", "monospace"]
    readonly property string iconFont: "Material Symbols Outlined"

    // -------- type scale (§8.6: three sizes + axis micro) --------
    readonly property int textDisplay: 30  // month/year header
    readonly property int textTitle:   18  // section titles, dialog titles
    readonly property int textBody:    13  // event blocks, todo rows
    readonly property int textCaption: 11  // hour axis, weekday tag, time chips
    readonly property int textInput:   15  // text fields

    readonly property int weightRegular: Font.Normal
    readonly property int weightMedium:  Font.Medium
    readonly property int weightBold:    Font.DemiBold

    // -------- spacing grid (§8.7: 8px base) --------
    readonly property int sp1: 4
    readonly property int sp2: 8
    readonly property int sp3: 12
    readonly property int sp4: 16
    readonly property int sp5: 20
    readonly property int sp6: 24
    readonly property int sp7: 32

    // -------- radii (§8.7) --------
    readonly property int radiusEvent: 8
    readonly property int radiusRow:   8
    readonly property int radiusCard:  14
    readonly property int radiusPill:  999

    // -------- Catppuccin pair: Latte (light) / Mocha (dark) --------
    // Base surfaces
    readonly property color bg:           dark ? "#1e1e2e" : "#eff1f5"   // base
    readonly property color bgSunken:     dark ? "#181825" : "#e6e9ef"   // mantle
    readonly property color surface:      dark ? "#313244" : "#ccd0da"   // surface0 (cards/dialogs)
    readonly property color surfaceHigh:  dark ? "#45475a" : "#bcc0cc"   // surface1 (hover)
    readonly property color border:       dark ? "#45475a" : "#dce0e8"   // soft border on cards

    // Foreground
    readonly property color fg:           dark ? "#cdd6f4" : "#4c4f69"   // text
    readonly property color fgMuted:      dark ? "#a6adc8" : "#5c5f77"   // subtext1
    readonly property color fgSubtle:     dark ? "#6c7086" : "#9ca0b0"   // overlay0

    // Dividers / hairlines (alpha over fg)
    readonly property color divider:      Qt.rgba(dark ? 1 : 0, dark ? 1 : 0, dark ? 1 : 0, 0.07)
    readonly property color hoverTint:    Qt.rgba(dark ? 1 : 0, dark ? 1 : 0, dark ? 1 : 0, 0.06)
    readonly property color gridLine:     Qt.rgba(dark ? 1 : 0, dark ? 1 : 0, dark ? 1 : 0, 0.06)
    readonly property color scrim:        Qt.rgba(0, 0, 0, 0.55)

    // Accent (mauve) — used for today pill, now-line, primary actions
    readonly property color accent:       dark ? "#cba6f7" : "#8839ef"
    readonly property color onAccent:     dark ? "#1e1e2e" : "#eff1f5"   // text on accent

    // Status
    readonly property color error:        dark ? "#f38ba8" : "#d20f39"
    readonly property color success:      dark ? "#a6e3a1" : "#40a02b"
    readonly property color warning:      dark ? "#fab387" : "#fe640b"

    // -------- source tints (§7) --------
    // Source-tinting maps to a soft category palette; agent/gcal get distinguishing hues.
    readonly property color tintAgent:    dark ? "#f9e2af" : "#df8e1d"   // yellow
    readonly property color tintGcal:     dark ? "#89dceb" : "#04a5e5"   // sky

    // -------- category palette (used by categoryColor()) --------
    // Catppuccin pairs picked to read well on both Latte and Mocha bgs.
    readonly property var _categoryPaletteDark:  ["#89b4fa", "#a6e3a1", "#cba6f7", "#f5c2e7", "#fab387", "#94e2d5", "#f9e2af", "#89dceb"]
    readonly property var _categoryPaletteLight: ["#1e66f5", "#40a02b", "#8839ef", "#ea76cb", "#fe640b", "#179299", "#df8e1d", "#04a5e5"]

    function categoryColor(category, source) {
        if (source === "agent") return tintAgent;
        if (source === "gcal")  return tintGcal;
        var palette = dark ? _categoryPaletteDark : _categoryPaletteLight;
        if (!category || category.length === 0) return accent;
        var h = 0;
        for (var i = 0; i < category.length; i++) {
            h = ((h * 31) + category.charCodeAt(i)) | 0;
        }
        return palette[Math.abs(h) % palette.length];
    }

    // Task pill colors
    readonly property color taskPending:  dark ? "#fab387" : "#fe640b"
    readonly property color taskDone:     dark ? "#a6e3a1" : "#40a02b"
    readonly property color onTaskPill:   dark ? "#1e1e2e" : "#eff1f5"

    // Done tasks fade out
    readonly property real doneOpacity: 0.45
}
