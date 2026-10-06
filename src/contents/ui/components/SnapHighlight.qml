import QtQuick
import "../components" as Components

// outlines the window being snapped to, with its title bar replaced by a filled bar holding the window title
Item {
    id: highlight

    property var config
    property string title: ""
    // height of the window's own title bar, 0 when it has none (borderless or client-side decorated)
    property real decorationHeight: 0
    readonly property real textHeight: titleMetrics.height
    readonly property real titleHeight: {
        if (config.windowSnapTitleHeightMode == 1)
            return config.windowSnapTitleHeight;

        if (config.windowSnapTitleHeightMode == 2 || decorationHeight <= 0)
            return textHeight + config.windowSnapTitlePadding * 2;

        return decorationHeight;
    }

    FontMetrics {
        id: titleMetrics

        font: titleText.font
    }

    Components.GlowShadow {
        anchors.fill: parent
        glowEnabled: config.windowSnapGlowEnabled
        glowColor: config.windowSnapGlowColor
        glowSize: config.windowSnapGlowSize
        shadowEnabled: config.windowSnapShadowEnabled
        shadowColor: config.windowSnapShadowColor
        shadowSize: config.windowSnapShadowSize

        // frame, its top edge is covered by the title bar
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: config.windowSnapColor
            border.width: config.windowSnapBorderWidth
        }

        Rectangle {
            width: parent.width
            height: highlight.titleHeight
            color: config.windowSnapColor
        }

    }

    Components.GlowShadow {
        x: config.windowSnapTitlePadding
        width: highlight.width - config.windowSnapTitlePadding * 2
        height: highlight.titleHeight
        glowEnabled: config.windowSnapFontGlowEnabled
        glowColor: config.windowSnapFontGlowColor
        glowSize: config.windowSnapFontGlowSize
        shadowEnabled: config.windowSnapFontShadowEnabled
        shadowColor: config.windowSnapFontShadowColor
        shadowSize: config.windowSnapFontShadowSize

        Text {
            id: titleText

            anchors.fill: parent
            text: highlight.title
            color: config.windowSnapFontColor
            font.family: config.windowSnapFontFamily || Qt.application.font.family
            font.pointSize: Math.max(1, config.windowSnapFontSize || 11)
            font.bold: config.windowSnapFontBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

    }

}
