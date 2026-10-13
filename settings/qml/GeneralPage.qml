import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.ScrollView {
    id: page
    contentWidth: availableWidth

    component Check: QQC2.CheckBox {
        required property string key
        checked: app.v[key]
        onToggled: app.set(key, checked)
    }
    component Choice: QQC2.ComboBox {
        required property string key
        currentIndex: app.v[key]
        onActivated: index => app.set(key, index)
    }

    Kirigami.FormLayout {
        width: page.availableWidth

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Zone selector" }
        Check { key: "enableZoneSelector"; text: "Enable the zone selector (appears when you drag a window to the top of the screen)" }
        Choice {
            key: "zoneSelectorTriggerDistance"; Kirigami.FormData.label: "Trigger distance:"
            enabled: app.v.enableZoneSelector
            model: ["Close", "Medium", "Far"]
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Zone overlay" }
        Check { key: "enableZoneOverlay"; text: "Enable the fullscreen zone overlay shown while moving a window" }
        Choice {
            key: "zoneOverlayShowWhen"; Kirigami.FormData.label: "Show overlay when:"
            enabled: app.v.enableZoneOverlay
            model: ["I start moving a window", "I press the toggle overlay shortcut"]
        }
        Choice {
            key: "zoneOverlayHighlightTarget"; Kirigami.FormData.label: "Highlight zone when:"
            enabled: app.v.enableZoneOverlay
            model: ["My cursor is above the zone indicator", "My cursor is anywhere in the zone"]
        }
        Choice {
            key: "zoneOverlayIndicatorDisplay"; Kirigami.FormData.label: "Indicator display:"
            enabled: app.v.enableZoneOverlay
            model: ["All zones", "Only target zone"]
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Edge snapping" }
        Check { key: "enableEdgeSnapping"; text: "Snap windows to zones by dragging them to the screen edge (disable KWin's own edge snapping first)" }
        Choice {
            key: "edgeSnappingTriggerDistance"; Kirigami.FormData.label: "Trigger distance:"
            enabled: app.v.enableEdgeSnapping
            model: ["Close", "Medium", "Far"]
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Behaviour" }
        Check { key: "rememberWindowGeometries"; text: "Remember and restore window geometries" }
        Check { key: "trackLayoutPerScreen"; text: "Track active layout per screen" }
        Check { key: "trackLayoutPerDesktop"; text: "Track active layout per virtual desktop" }
        Check { key: "autoSnapAllNew"; text: "Automatically snap all new windows" }
        Check { key: "showOsdMessages"; text: "Display OSD messages" }
        Check { key: "fadeWindowsWhileMoving"; text: "Fade windows while moving" }
    }
}
