import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "ColorSpecCore.js" as Core

// Slider (no tick marks) with a strip above it painting the color each value gives, and the value beside it
RowLayout {
    id: root

    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    // v => {r, g, b, a} for a slider value
    property var colorAt: null
    // change it whenever colorAt would give other colors, to repaint the strip
    property var repaintKey
    property bool checker: false
    property string suffix: ""
    signal moved

    onRepaintKeyChanged: strip.requestPaint()
    onColorAtChanged: strip.requestPaint()

    ColumnLayout {
        spacing: 2
        Canvas {
            id: strip
            // spans the handle's travel, so each color sits right above its value
            Layout.leftMargin: slider.leftPadding + slider.handle.width / 2
            Layout.preferredWidth: Math.max(1, slider.availableWidth - slider.handle.width)
            Layout.preferredHeight: Kirigami.Units.smallSpacing * 2
            opacity: root.enabled ? 1 : 0.4
            onWidthChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                if (!root.colorAt || width <= 0)
                    return;
                if (root.checker)
                    for (let x = 0; x < width; x += 4)
                        for (let y = 0; y < height; y += 4) {
                            ctx.fillStyle = (x + y) % 8 ? "#999999" : "#666666";
                            ctx.fillRect(x, y, 4, 4);
                        }
                const g = ctx.createLinearGradient(0, 0, width, 0);
                const n = 24;
                for (let i = 0; i <= n; ++i) {
                    const c = root.colorAt(slider.from + (slider.to - slider.from) * i / n);
                    g.addColorStop(i / n, Core.css({ r: c.r, g: c.g, b: c.b, a: c.a === undefined ? 1 : c.a }));
                }
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, width, height);
            }
        }
        QQC2.Slider {
            id: slider
            from: 0
            to: 100
            stepSize: 5
            snapMode: QQC2.Slider.SnapAlways
            Kirigami.StyleHints.tickMarkStepSize: -1
            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
            onMoved: root.moved()
        }
    }
    QQC2.Label {
        Layout.alignment: Qt.AlignBottom
        Layout.minimumWidth: Kirigami.Units.gridUnit * 2.5
        text: (slider.value > 0 && slider.from < 0 ? "+" : "") + Math.round(slider.value) + root.suffix
    }
}
