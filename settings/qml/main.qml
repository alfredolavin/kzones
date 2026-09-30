import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// KZones settings (see kzones_settings.py). Values are kept as typed JS values in `v`; Apply writes the changed
// ones to kwinrc and, with "Reload script", loads the script again so it picks them up.
Kirigami.ApplicationWindow {
    id: app

    title: "KZones Settings"
    width: Kirigami.Units.gridUnit * 44
    height: Kirigami.Units.gridUnit * 38

    readonly property var defaults: ({
        enableZoneSelector: true, zoneSelectorTriggerDistance: 1,
        enableZoneOverlay: true, zoneOverlayShowWhen: 0, zoneOverlayHighlightTarget: 0, zoneOverlayIndicatorDisplay: 0,
        enableEdgeSnapping: false, edgeSnappingTriggerDistance: 1,
        rememberWindowGeometries: true, trackLayoutPerScreen: false, trackLayoutPerDesktop: false,
        autoSnapAllNew: false, showOsdMessages: true, fadeWindowsWhileMoving: false,
        layoutsJson: "", filterMode: 0, filterList: "",
        colorSpecs: "{}", colorizeBy: 0, vividLightness: 72, vividChroma: 17, vividHueStart: 20, vividHueRange: 360,
        pollingRate: 100, enableDebugLogging: false, enableDebugOverlay: false
    })
    property var v: Object.assign({}, defaults)
    property var dirty: ({})
    readonly property bool hasChanges: Object.keys(dirty).length > 0
    property string status: ""

    function load() {
        const stored = JSON.parse(backend.readAll(JSON.stringify(Object.keys(defaults))));
        const out = Object.assign({}, defaults);
        for (const k in stored) {
            const d = defaults[k];
            out[k] = typeof d === "boolean" ? stored[k] === "true" : typeof d === "number" ? Number(stored[k]) : stored[k];
        }
        v = out;
        dirty = ({});
    }
    function set(key, value) {
        if (v[key] === value)
            return;
        const n = Object.assign({}, v);
        n[key] = value;
        v = n;
        const d = Object.assign({}, dirty);
        d[key] = true;
        dirty = d;
    }
    function apply() {
        for (const k in dirty)
            backend.write(k, String(v[k]));
        dirty = ({});
        status = i18n("Saved");
    }
    function applyAndReload() {
        apply();
        const err = backend.reload();
        status = err ? err : i18n("Saved and script reloaded");
    }

    Component.onCompleted: load()


    pageStack.initialPage: Kirigami.Page {
        title: app.title
        padding: 0

        header: QQC2.TabBar {
            id: tabs
            QQC2.TabButton { text: "General" }
            QQC2.TabButton { text: "Layouts" }
            QQC2.TabButton { text: "Customization" }
            QQC2.TabButton { text: "Filters" }
            QQC2.TabButton { text: "Advanced" }
        }

        StackLayout {
            anchors.fill: parent
            currentIndex: tabs.currentIndex
            GeneralPage {}
            LayoutsPage {}
            CustomizationPage {}
            FiltersPage {}
            AdvancedPage {}
        }

        footer: QQC2.ToolBar {
            position: QQC2.ToolBar.Footer
            RowLayout {
                anchors.fill: parent
                QQC2.Label {
                    Layout.fillWidth: true
                    leftPadding: Kirigami.Units.largeSpacing
                    text: app.status || (app.hasChanges ? "Unsaved changes" : "")
                    elide: Text.ElideRight
                    opacity: 0.8
                }
                QQC2.Button { text: "Revert"; icon.name: "edit-undo"; enabled: app.hasChanges; onClicked: { app.load(); app.status = "" } }
                QQC2.Button { text: "Apply"; icon.name: "dialog-ok-apply"; enabled: app.hasChanges; onClicked: app.apply() }
                QQC2.Button {
                    text: "Apply and reload script"
                    icon.name: "view-refresh"
                    highlighted: true
                    onClicked: app.applyAndReload()
                    QQC2.ToolTip.text: "Unloads and loads the KZones KWin script again so it reads the new settings"
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }
    }
}
