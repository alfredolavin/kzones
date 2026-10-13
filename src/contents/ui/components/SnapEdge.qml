import QtQuick
import "../components" as Components

// marks a screen edge the moving window snaps to
Components.GlowShadow {
    property var config

    glowEnabled: config.windowSnapGlowEnabled
    glowColor: config.windowSnapGlowColor
    glowSize: config.windowSnapGlowSize
    shadowEnabled: config.windowSnapShadowEnabled
    shadowColor: config.windowSnapShadowColor
    shadowSize: config.windowSnapShadowSize

    Rectangle {
        anchors.fill: parent
        color: config.windowSnapColor
    }

}
