import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQControls

import "ColorSpecCore.js" as Core

// A configurable color (see ColorSpecCore.js): shows the color and how it is made; a click opens a window to
// pick a fixed color or one of the host's sources, adjust its luminosity, chroma, hue and opacity, and preview
// the result. This is the one place the control lives; hosts only say what the sources are:
//   sources      [{ id, name, options?: [{ id, name }], optionLabel? }] besides "fixed"; a source with options
//                (e.g. the theme's colors) gets a chooser, the choice being stored as `sys`
//   baseColor    (src, fixedColor, context, option) => {r, g, b, a}, the color a source stands for
//   context      passed to baseColor (theme palette, active gradient …); while the window is open the
//                context of `previewExtra`'s item is used instead, when there is one
//   previewExtra optional Component shown in the window's Preview section; its root has `property var context`
//   decoration   optional Component drawn over the bottom edge of swatches (root has `property var context`)
// The new value comes out through `edited`, so a binding to the setting stays intact.
QQC2.Button {
    id: btn

    // stored spec string
    property string value
    property var sources: []
    property var baseColor: (src, fixedColor, context, option) => fixedColor
    property var context: null
    property Component previewExtra: null
    property Component decoration: null
    property string dialogTitle: i18n("Choose a color")
    signal edited(string value)

    readonly property var sourceIds: ["fixed"].concat(sources.map(s => s.id))
    readonly property var spec: Core.parse(value, sourceIds)
    readonly property var activeContext: dialog.visible && extraLoader.item ? extraLoader.item.context : context

    function sourceName(src) {
        const s = sources.find(x => x.id === src);
        return s ? s.name : i18n("Fixed");
    }
    function sourceOf(src) {
        return sources.find(x => x.id === src) || null;
    }
    function optionsOf(src) {
        const s = sourceOf(src);
        return s && s.options ? s.options : [];
    }
    function optionName(src, id) {
        const o = optionsOf(src).find(x => x.id === id);
        return o ? o.name : "";
    }
    function baseOf(s, ctx) {
        return baseColor(s.src, s.color, ctx, s.sys);
    }
    function summary(s) {
        const opt = optionName(s.src, s.sys);
        const parts = [s.src === "fixed" ? Core.hexOf(s.color).replace(/^#ff/, "#") : sourceName(s.src) + (opt ? ": " + opt : "")];
        const adj = Core.adjustments(s);
        if (adj)
            parts.push(adj);
        if (s.a < 100)
            parts.push(s.a + " %");
        return parts.join(" · ");
    }
    function qcolor(c) {
        return Qt.rgba(c.r, c.g, c.b, c.a === undefined ? 1 : c.a);
    }

    readonly property color resolved: qcolor(Core.apply(spec, baseOf(spec, context)))

    QQC2.ToolTip.text: i18n("Click to change")
    QQC2.ToolTip.visible: hovered
    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

    leftPadding: 3
    rightPadding: 3

    // transparent, with a small shadow around it; a tint while hovered or pressed, a ring when focused
    background: Item {
        implicitWidth: Kirigami.Units.gridUnit * 3
        implicitHeight: Kirigami.Units.gridUnit * 1.6
        readonly property color hl: Kirigami.Theme.highlightColor
        BoxShadow {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            blur: 4
            offsetY: 1
            color: Qt.rgba(0, 0, 0, 0.3)
        }
        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            color: btn.pressed ? Qt.rgba(parent.hl.r, parent.hl.g, parent.hl.b, 0.3)
                 : btn.hovered ? Qt.rgba(parent.hl.r, parent.hl.g, parent.hl.b, 0.15) : "transparent"
            border.width: btn.visualFocus ? 1 : 0
            border.color: parent.hl
        }
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing
        Swatch {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.6
            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.1
            color: btn.resolved
            // gradient sources show a tiny gradient underline
            decoration: btn.spec.src === "fixed" ? null : btn.decoration
            context: btn.context
        }
        QQC2.Label {
            text: btn.summary(btn.spec)
            elide: Text.ElideRight
            Layout.maximumWidth: Kirigami.Units.gridUnit * 12
        }
    }

    onClicked: {
        editor.load(spec);
        dialog.open();
    }

    // A window of its own, sized to its content (not limited by the settings dialog), scrolling when the
    // screen is smaller than that
    Window {
        id: dialog
        title: btn.dialogTitle
        transientParent: btn.Window.window
        modality: Qt.WindowModal
        flags: Qt.Dialog
        color: Kirigami.Theme.backgroundColor

        readonly property int margin: Kirigami.Units.largeSpacing * 2
        readonly property int fitWidth: editor.implicitWidth + 2 * margin + scroll.effectiveScrollBarWidth
        readonly property int fitHeight: editor.implicitHeight + buttons.implicitHeight + 3 * margin
        minimumWidth: Math.min(fitWidth, Screen.desktopAvailableWidth)
        minimumHeight: Math.min(Kirigami.Units.gridUnit * 12, fitHeight)
        width: minimumWidth
        height: Math.min(fitHeight, Screen.desktopAvailableHeight * 0.9)

        function open() {
            width = minimumWidth;
            height = Math.min(fitHeight, Screen.desktopAvailableHeight * 0.9);
            show();
            raise();
            requestActivate();
        }
        function accept() {
            btn.edited(Core.stringify(editor.edited));
            close();
        }

        Shortcut { sequence: "Escape"; onActivated: dialog.close() }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: dialog.margin
            spacing: dialog.margin

            QQC2.ScrollView {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth

                Kirigami.FormLayout {
                    id: editor
                    width: scroll.availableWidth

                    // the spec being edited; written back only on OK
                    property var edited: Core.defaults()
                    // base color of the edited source (before adjustments) in the preview
                    readonly property var base: btn.baseOf(edited, btn.activeContext)
                    readonly property var result: Core.apply(edited, base)
                    readonly property string key: JSON.stringify([edited, Core.hexOf(base)])

                    function load(s) {
                        edited = Object.assign({}, s);
                        optionCombo.currentIndex = Math.max(0, btn.optionsOf(s.src).findIndex(o => o.id === s.sys));
                        luminosity.value = s.l;
                        chroma.value = s.c;
                        hue.value = s.h;
                        opacitySlider.value = s.a;
                        fixedColor.color = btn.qcolor(s.color);
                    }
                    function set(field, v) {
                        const e = Object.assign({}, edited);
                        e[field] = v;
                        edited = e;
                    }

                    // ---- source ----
                    QQC2.ButtonGroup { id: sourceGroup }
                    GridLayout {
                        Kirigami.FormData.label: i18n("Source:")
                        columns: 2
                        columnSpacing: Kirigami.Units.largeSpacing
                        Repeater {
                            model: btn.sourceIds
                            RowLayout {
                                required property string modelData
                                spacing: Kirigami.Units.smallSpacing
                                QQC2.RadioButton {
                                    QQC2.ButtonGroup.group: sourceGroup
                                    text: btn.sourceName(modelData)
                                    checked: editor.edited.src === modelData
                                    onToggled: if (checked) editor.set("src", modelData)
                                }
                                // what this source gives in the preview, before adjustments
                                Swatch {
                                    Layout.preferredWidth: Kirigami.Units.gridUnit
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 0.8
                                    color: btn.qcolor(btn.baseColor(modelData, editor.edited.color, btn.activeContext, editor.edited.sys))
                                }
                            }
                        }
                    }
                    KQControls.ColorButton {
                        id: fixedColor
                        Kirigami.FormData.label: i18n("Fixed color:")
                        enabled: editor.edited.src === "fixed"
                        showAlphaChannel: true
                        onAccepted: c => editor.set("color", { r: c.r, g: c.g, b: c.b, a: c.a })
                    }

                    QQC2.ComboBox {
                        id: optionCombo
                        readonly property var choices: btn.optionsOf(editor.edited.src)
                        readonly property var owner: btn.sources.find(x => x.options && x.options.length) || null
                        visible: !!owner
                        Kirigami.FormData.label: owner && owner.optionLabel ? owner.optionLabel : i18n("Variant:")
                        enabled: choices.length > 0
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                        model: choices.length ? choices : (owner ? owner.options : [])
                        textRole: "name"
                        onActivated: index => editor.set("sys", model[index].id)
                        delegate: QQC2.ItemDelegate {
                            required property var modelData
                            required property int index
                            width: optionCombo.popup.width
                            highlighted: optionCombo.highlightedIndex === index
                            contentItem: RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Swatch {
                                    Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
                                    Layout.preferredHeight: Kirigami.Units.gridUnit * 0.9
                                    color: btn.qcolor(btn.baseColor(editor.edited.src, editor.edited.color, btn.activeContext, modelData.id))
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // ---- adjustments ----
                    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Adjustments (OKLCH)") }

                    ColorStripSlider {
                        id: luminosity
                        Kirigami.FormData.label: i18n("Luminosity:")
                        from: -100
                        colorAt: v => Core.shade(editor.base, v, editor.edited.c, editor.edited.h)
                        repaintKey: editor.key
                        onMoved: editor.set("l", value)
                    }
                    ColorStripSlider {
                        id: chroma
                        Kirigami.FormData.label: i18n("Chroma:")
                        from: -100
                        colorAt: v => Core.shade(editor.base, editor.edited.l, v, editor.edited.h)
                        repaintKey: editor.key
                        onMoved: editor.set("c", value)
                    }
                    ColorStripSlider {
                        id: hue
                        Kirigami.FormData.label: i18n("Hue offset:")
                        from: -180
                        to: 180
                        stepSize: 5
                        suffix: "°"
                        colorAt: v => Core.shade(editor.base, editor.edited.l, editor.edited.c, v)
                        repaintKey: editor.key
                        onMoved: editor.set("h", value)
                    }
                    ColorStripSlider {
                        id: opacitySlider
                        Kirigami.FormData.label: i18n("Opacity:")
                        checker: true
                        suffix: " %"
                        colorAt: v => {
                            const c = Core.shade(editor.base, editor.edited.l, editor.edited.c, editor.edited.h);
                            return { r: c.r, g: c.g, b: c.b, a: (editor.base.a === undefined ? 1 : editor.base.a) * v / 100 };
                        }
                        repaintKey: editor.key
                        onMoved: editor.set("a", value)
                    }

                    // ---- preview ----
                    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Preview") }

                    Loader {
                        id: extraLoader
                        Layout.fillWidth: true
                        sourceComponent: btn.previewExtra
                        visible: active && status === Loader.Ready
                    }
                    RowLayout {
                        Kirigami.FormData.label: i18n("Result:")
                        spacing: Kirigami.Units.smallSpacing
                        Swatch {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.6
                            color: btn.qcolor(editor.base)
                        }
                        QQC2.Label { text: "→" }
                        Swatch {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 5
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 1.6
                            color: btn.qcolor(editor.result)
                        }
                        QQC2.Label {
                            text: btn.summary(editor.edited)
                            opacity: 0.8
                        }
                    }
                }
            }

            QQC2.DialogButtonBox {
                id: buttons
                Layout.fillWidth: true
                standardButtons: QQC2.DialogButtonBox.Ok | QQC2.DialogButtonBox.Cancel
                onAccepted: dialog.accept()
                onRejected: dialog.close()
            }
        }
    }
}
