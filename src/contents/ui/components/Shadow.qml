import QtQuick
import QtQuick.Effects

MultiEffect {
    property Item target: null
    property var config

    anchors.fill: target
    visible: target ? target.visible : false
    opacity: target ? target.opacity : 0
    scale: target ? target.scale : 1
    source: target
    shadowEnabled: true
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 0
    shadowBlur: 1
    shadowColor: colorHelper.pick(config, "shadow", colorHelper.getShadowColor())
    autoPaddingEnabled: true

    ColorHelper {
        id: colorHelper
    }

}
