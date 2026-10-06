import QtQuick
import QtQuick.Effects

// renders its children with an optional glow and an optional drop shadow
Item {
    id: effects

    default property alias content: inner.data
    property bool glowEnabled: false
    property color glowColor: "white"
    property int glowSize: 16
    property bool shadowEnabled: false
    property color shadowColor: "black"
    property int shadowSize: 16
    readonly property int shadowOffset: Math.round(shadowSize / 3)
    // room around the content so the glow and shadow are not clipped, as each pass is limited to its own bounds
    readonly property int pad: Math.max(glowEnabled ? glowSize : 0, shadowEnabled ? shadowSize + shadowOffset : 0) + 2

    Item {
        id: host

        x: -effects.pad
        y: -effects.pad
        width: effects.width + effects.pad * 2
        height: effects.height + effects.pad * 2
        visible: false

        Item {
            id: inner

            x: effects.pad
            y: effects.pad
            width: effects.width
            height: effects.height
        }

    }

    MultiEffect {
        id: glow

        anchors.fill: host
        source: host
        visible: false
        autoPaddingEnabled: false
        shadowEnabled: effects.glowEnabled
        shadowColor: effects.glowColor
        shadowBlur: 1
        blurMax: Math.max(1, Math.min(64, effects.glowSize))
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    MultiEffect {
        anchors.fill: host
        source: glow
        autoPaddingEnabled: false
        shadowEnabled: effects.shadowEnabled
        shadowColor: effects.shadowColor
        shadowBlur: 1
        blurMax: Math.max(1, Math.min(64, effects.shadowSize))
        shadowHorizontalOffset: 0
        shadowVerticalOffset: effects.shadowOffset
    }

}
