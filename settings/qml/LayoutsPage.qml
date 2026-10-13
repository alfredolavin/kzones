import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQControls

import "../../src/contents/code/Theming.js" as Theming

// Layouts: a visual editor (the standalone zone editor, merged in) with a color for each zone, and the raw JSON.
// Draw a zone by dragging on empty space, move it by its body, resize it by the corner handle. The layouts are kept
// in `layouts` (parsed from the layoutsJson setting) and written back as JSON on every change.
ColumnLayout {
    id: page
    spacing: 0

    readonly property var defaultLayouts: [
        { name: "Priority Grid", padding: 0, zones: [{ x: 0, y: 0, height: 100, width: 25 }, { x: 25, y: 0, height: 100, width: 50 }, { x: 75, y: 0, height: 100, width: 25 }] },
        { name: "Quadrant Grid", zones: [{ x: 0, y: 0, height: 50, width: 50 }, { x: 0, y: 50, height: 50, width: 50 }, { x: 50, y: 50, height: 50, width: 50 }, { x: 50, y: 0, height: 50, width: 50 }] }
    ]
    property var layouts: []
    property int cur: 0
    property int sel: -1
    property string written: ""
    property bool snapOn: true
    property int snapStep: 5
    readonly property bool jsonMode: viewTabs.currentIndex === 1
    readonly property var curLayout: layouts[cur] || null

    ListModel { id: zones }    // x, y, w, h (percent), color ("" or "#rrggbb"), extra (JSON of the other keys)

    // ---- data ----
    function parseLayouts(text) {
        let data;
        try { data = text ? JSON.parse(text) : JSON.parse(JSON.stringify(defaultLayouts)); } catch (e) { return null; }
        if (!Array.isArray(data))
            return null;
        return data.map(l => Object.assign({ name: "Layout", padding: 0 }, l, { zones: (l.zones || []) }));
    }
    function reload() {
        const parsed = parseLayouts(app.v.layoutsJson);
        if (!parsed)
            return;
        layouts = parsed.length ? parsed : [{ name: "Layout 1", padding: 0, zones: [] }];
        cur = Math.min(cur, layouts.length - 1);
        loadZones();
        written = app.v.layoutsJson;
    }
    function loadZones() {
        zones.clear();
        sel = -1;
        (curLayout ? curLayout.zones : []).forEach(z => {
            const extra = Object.assign({}, z);
            ["x", "y", "width", "height", "color"].forEach(k => delete extra[k]);
            zones.append({ x: Number(z.x) || 0, y: Number(z.y) || 0, w: Number(z.width) || 0, h: Number(z.height) || 0,
                           color: z.color || "", extra: JSON.stringify(extra) });
        });
    }
    function commit() {
        const out = layouts.map((l, i) => {
            if (i !== cur)
                return l;
            const z = [];
            for (let k = 0; k < zones.count; ++k) {
                const m = zones.get(k);
                const o = { x: m.x, y: m.y, width: m.w, height: m.h };
                if (m.color)
                    o.color = m.color;
                z.push(Object.assign(JSON.parse(m.extra), o));
            }
            return Object.assign({}, l, { zones: z });
        });
        layouts = out;
        written = JSON.stringify(out, null, 2);
        app.set("layoutsJson", written);
    }
    function commitLayouts() {
        written = JSON.stringify(layouts, null, 2);
        app.set("layoutsJson", written);
    }
    Connections {
        target: app
        function onVChanged() {
            if (app.v.layoutsJson !== page.written)
                page.reload();
        }
    }
    Component.onCompleted: reload()

    function snapped(v) { return snapOn ? Math.round(v / snapStep) * snapStep : Math.round(v * 10) / 10; }
    function clampPct(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
    function addZone(x, y, w, h) {
        zones.append({ x: x, y: y, w: w, h: h, color: "", extra: "{}" });
        sel = zones.count - 1;
        commit();
    }
    function removeSel() {
        if (sel < 0)
            return;
        zones.remove(sel);
        sel = -1;
        commit();
    }
    function hex(c) {
        const x = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + x(c.r) + x(c.g) + x(c.b);
    }
    // the vivid color (Customization settings) a zone gets by its index and place
    function vividFor(i) {
        const m = zones.get(i);
        return hex(Theming.resolve({ colorSpecs: { z: '{"src":"vivid","color":"#ffffffff","l":0,"c":0,"a":100}' },
                                     colorizeBy: app.v.colorizeBy, vividLightness: app.v.vividLightness, vividChroma: app.v.vividChroma,
                                     vividHueStart: app.v.vividHueStart, vividHueRange: app.v.vividHueRange },
                                   "z", "#000000", Theming.zoneCtx({ x: m.x, y: m.y, width: m.w, height: m.h }, i, zones.count)));
    }
    function colorAll(vivid) {
        for (let i = 0; i < zones.count; ++i)
            zones.setProperty(i, "color", vivid ? vividFor(i) : "");
        commit();
    }

    // ---- view switch ----
    QQC2.TabBar {
        id: viewTabs
        Layout.fillWidth: true
        QQC2.TabButton { text: "Visual editor" }
        QQC2.TabButton { text: "JSON" }
    }

    StackLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        currentIndex: viewTabs.currentIndex

        // ================= visual =================
        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Layout.margins: Kirigami.Units.largeSpacing

            // layouts list
            ColumnLayout {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                Layout.fillHeight: true
                QQC2.ToolBar {
                    Layout.fillWidth: true
                    RowLayout {
                        anchors.fill: parent
                        component Tool: QQC2.ToolButton {
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }
                        Tool { icon.name: "list-add"; text: "New layout"
                            onClicked: { page.layouts = page.layouts.concat([{ name: "Layout " + (page.layouts.length + 1), padding: 0, zones: [] }]); page.cur = page.layouts.length - 1; page.loadZones(); page.commitLayouts(); } }
                        Tool { icon.name: "edit-copy"; text: "Duplicate layout"
                            onClicked: { const c = JSON.parse(JSON.stringify(page.layouts[page.cur])); c.name += " copy"; page.layouts = page.layouts.concat([c]); page.cur = page.layouts.length - 1; page.loadZones(); page.commitLayouts(); } }
                        Tool { icon.name: "edit-delete"; text: "Delete layout"; enabled: page.layouts.length > 1
                            onClicked: { const l = page.layouts.slice(); l.splice(page.cur, 1); page.layouts = l; page.cur = Math.max(0, page.cur - 1); page.loadZones(); page.commitLayouts(); } }
                        Item { Layout.fillWidth: true }
                    }
                }
                ListView {
                    id: layoutList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: page.layouts
                    delegate: QQC2.ItemDelegate {
                        required property var modelData
                        required property int index
                        width: layoutList.width
                        text: modelData.name
                        highlighted: index === page.cur
                        onClicked: { page.cur = index; page.loadZones(); }
                    }
                    Rectangle { anchors.fill: parent; z: -1; color: "transparent"; border.color: Kirigami.Theme.disabledTextColor; opacity: 0.4 }
                }
                QQC2.TextField {
                    Layout.fillWidth: true
                    placeholderText: "Layout name"
                    text: page.curLayout ? page.curLayout.name : ""
                    onEditingFinished: if (page.curLayout && text && text !== page.curLayout.name) {
                        const l = page.layouts.slice();
                        l[page.cur] = Object.assign({}, l[page.cur], { name: text });
                        page.layouts = l;
                        page.commitLayouts();
                    }
                }
                RowLayout {
                    QQC2.Label { text: "Padding:" }
                    QQC2.SpinBox {
                        from: 0; to: 100
                        value: page.curLayout ? (page.curLayout.padding || 0) : 0
                        onValueModified: {
                            const l = page.layouts.slice();
                            l[page.cur] = Object.assign({}, l[page.cur], { padding: value });
                            page.layouts = l;
                            page.commit();
                        }
                    }
                }
                RowLayout {
                    QQC2.CheckBox { text: "Snap to"; checked: page.snapOn; onToggled: page.snapOn = checked }
                    QQC2.SpinBox { from: 1; to: 25; value: page.snapStep; enabled: page.snapOn; onValueModified: page.snapStep = value; textFromValue: v => v + " %" }
                }
            }

            // canvas + zone form
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.smallSpacing

                Item {
                    id: stage
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Rectangle {
                        id: canvas
                        readonly property real ratio: 16 / 9
                        width: Math.min(stage.width, stage.height * ratio)
                        height: width / ratio
                        anchors.centerIn: parent
                        color: Qt.rgba(0, 0, 0, 0.25)
                        border.color: Kirigami.Theme.disabledTextColor
                        border.width: 1
                        clip: true

                        // grid
                        Repeater {
                            model: page.snapOn ? Math.floor(100 / page.snapStep) - 1 : 0
                            Item {
                                required property int index
                                Rectangle { x: (index + 1) * page.snapStep / 100 * canvas.width; width: 1; height: canvas.height; color: Qt.rgba(1, 1, 1, 0.06) }
                                Rectangle { y: (index + 1) * page.snapStep / 100 * canvas.height; height: 1; width: canvas.width; color: Qt.rgba(1, 1, 1, 0.06) }
                            }
                        }

                        // draw a new zone on empty space
                        MouseArea {
                            id: drawArea
                            anchors.fill: parent
                            property real sx: 0
                            property real sy: 0
                            property bool drawing: false
                            property rect r: Qt.rect(0, 0, 0, 0)
                            onPressed: mouse => { page.sel = -1; sx = page.clampPct(page.snapped(mouse.x / width * 100), 0, 100); sy = page.clampPct(page.snapped(mouse.y / height * 100), 0, 100); drawing = true; r = Qt.rect(sx, sy, 0, 0); }
                            onPositionChanged: mouse => {
                                const ex = page.clampPct(page.snapped(mouse.x / width * 100), 0, 100), ey = page.clampPct(page.snapped(mouse.y / height * 100), 0, 100);
                                r = Qt.rect(Math.min(sx, ex), Math.min(sy, ey), Math.abs(ex - sx), Math.abs(ey - sy));
                            }
                            onReleased: { drawing = false; if (r.width >= 2 && r.height >= 2) page.addZone(r.x, r.y, r.width, r.height); r = Qt.rect(0, 0, 0, 0); }
                        }
                        Rectangle {
                            visible: drawArea.drawing
                            x: drawArea.r.x / 100 * canvas.width; y: drawArea.r.y / 100 * canvas.height
                            width: drawArea.r.width / 100 * canvas.width; height: drawArea.r.height / 100 * canvas.height
                            color: Qt.rgba(1, 1, 1, 0.1); border.color: "white"; border.width: 1
                        }

                        Repeater {
                            model: zones
                            Rectangle {
                                id: zr
                                required property int index
                                readonly property var m: zones.get(index)
                                readonly property bool selected: page.sel === index
                                readonly property color base: m && m.color ? m.color : Kirigami.Theme.highlightColor
                                x: m ? m.x / 100 * canvas.width : 0
                                y: m ? m.y / 100 * canvas.height : 0
                                width: m ? m.w / 100 * canvas.width : 0
                                height: m ? m.h / 100 * canvas.height : 0
                                color: Qt.rgba(base.r, base.g, base.b, selected ? 0.5 : 0.3)
                                border.color: selected ? Kirigami.Theme.textColor : base
                                border.width: selected ? 2 : 1
                                radius: 3

                                QQC2.Label {
                                    anchors.centerIn: parent
                                    text: (zr.index + 1) + "\n" + (zr.m ? Math.round(zr.m.w) + "×" + Math.round(zr.m.h) : "")
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Kirigami.Theme.textColor
                                    style: Text.Outline
                                    styleColor: Qt.rgba(0, 0, 0, 0.6)
                                }
                                // move
                                MouseArea {
                                    anchors.fill: parent
                                    property real px: 0
                                    property real py: 0
                                    property real ox: 0
                                    property real oy: 0
                                    onPressed: mouse => { page.sel = zr.index; const p = mapToItem(canvas, mouse.x, mouse.y); px = p.x; py = p.y; ox = zr.m.x; oy = zr.m.y; }
                                    onPositionChanged: mouse => {
                                        if (!pressed)
                                            return;
                                        const p = mapToItem(canvas, mouse.x, mouse.y);
                                        const m = zr.m;
                                        zones.setProperty(zr.index, "x", page.clampPct(page.snapped(ox + (p.x - px) / canvas.width * 100), 0, 100 - m.w));
                                        zones.setProperty(zr.index, "y", page.clampPct(page.snapped(oy + (p.y - py) / canvas.height * 100), 0, 100 - m.h));
                                    }
                                    onReleased: page.commit()
                                }
                                // resize
                                Rectangle {
                                    visible: zr.selected
                                    width: 12; height: 12
                                    anchors.right: parent.right; anchors.bottom: parent.bottom
                                    color: Kirigami.Theme.textColor
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        onPositionChanged: mouse => {
                                            if (!pressed)
                                                return;
                                            const p = mapToItem(canvas, mouse.x, mouse.y);
                                            const m = zr.m;
                                            zones.setProperty(zr.index, "w", Math.max(2, page.clampPct(page.snapped(p.x / canvas.width * 100 - m.x), 2, 100 - m.x)));
                                            zones.setProperty(zr.index, "h", Math.max(2, page.clampPct(page.snapped(p.y / canvas.height * 100 - m.y), 2, 100 - m.y)));
                                        }
                                        onReleased: page.commit()
                                    }
                                }
                            }
                        }
                        Keys.onDeletePressed: page.removeSel()
                        focus: true
                    }
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: "Drag on empty space to draw a zone; drag a zone to move it, its corner to resize it, Delete removes it."
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                }

                // selected zone
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    enabled: page.sel >= 0
                    readonly property var m: page.sel >= 0 ? zones.get(page.sel) : null

                    component Pct: QQC2.SpinBox {
                        required property string field
                        from: 0; to: 100
                        editable: true
                        value: parent && parent.m ? Math.round(parent.m[field]) : 0
                        textFromValue: v => v + " %"
                        onValueModified: { zones.setProperty(page.sel, field, value); page.commit(); }
                    }
                    RowLayout {
                        Kirigami.FormData.label: "Position:"
                        Pct { field: "x" }
                        Pct { field: "y" }
                    }
                    RowLayout {
                        Kirigami.FormData.label: "Size:"
                        Pct { field: "w" }
                        Pct { field: "h" }
                    }
                    RowLayout {
                        Kirigami.FormData.label: "Color:"
                        KQControls.ColorButton {
                            id: zoneColor
                            color: parent.parent.m && parent.parent.m.color ? parent.parent.m.color : Kirigami.Theme.highlightColor
                            onAccepted: c => { zones.setProperty(page.sel, "color", page.hex(c)); page.commit(); }
                        }
                        QQC2.Button { text: "Vivid"; icon.name: "color-management"; onClicked: { zones.setProperty(page.sel, "color", page.vividFor(page.sel)); page.commit(); }
                            QQC2.ToolTip.text: "Use the color the vivid palette (Customization tab) gives this zone"; QQC2.ToolTip.visible: hovered }
                        QQC2.Button { text: "None"; icon.name: "edit-clear"; onClicked: { zones.setProperty(page.sel, "color", ""); page.commit(); } }
                    }
                    QQC2.Button {
                        text: "Delete zone"; icon.name: "edit-delete"
                        onClicked: page.removeSel()
                    }
                }
                RowLayout {
                    QQC2.Button { text: "Colorize all zones (vivid)"; icon.name: "color-management"; onClicked: page.colorAll(true)
                        QQC2.ToolTip.text: "Give every zone of this layout its vivid color, by index or position as set in Customization"; QQC2.ToolTip.visible: hovered }
                    QQC2.Button { text: "Clear zone colors"; icon.name: "edit-clear"; onClicked: page.colorAll(false) }
                }
            }
        }

        // ================= JSON =================
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                wrapMode: Text.WordWrap
                text: "Layouts as JSON: a list of { name, padding, zones: [{ x, y, width, height, color?, indicator? }] } with positions in percent."
                opacity: 0.8
            }
            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Kirigami.Units.largeSpacing
                QQC2.TextArea {
                    id: jsonEdit
                    font.family: "monospace"
                    text: page.jsonMode || !activeFocus ? (app.v.layoutsJson || JSON.stringify(page.defaultLayouts, null, 2)) : text
                    wrapMode: TextEdit.NoWrap
                    onTextChanged: if (activeFocus) app.set("layoutsJson", text)
                    color: page.parseLayouts(text) ? Kirigami.Theme.textColor : Kirigami.Theme.negativeTextColor
                }
            }
            QQC2.Label {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                visible: !page.parseLayouts(app.v.layoutsJson)
                text: "The JSON is not valid: the script would fall back to its default layouts"
                color: Kirigami.Theme.negativeTextColor
            }
        }
    }
}
