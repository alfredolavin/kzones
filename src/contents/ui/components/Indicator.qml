import QtQuick
import "../components" as Components

Rectangle {
    id: indicator

    property int activeZone: 0
    property bool hovering: false
    property var zones: []
    property var config
    // for the colors: where `zones` starts among the layout's zones, and how many the layout has
    property int baseIndex: 0
    property int total: zones.length

    width: parent.width
    height: parent.height
    color: "transparent"
    opacity: 1

    Repeater {
        id: indicators

        model: zones

        Item {
            id: zone

            x: ((modelData.x / 100) * (indicator.width))
            y: ((modelData.y / 100) * (indicator.height))
            width: ((modelData.width / 100) * (indicator.width))
            height: ((modelData.height / 100) * (indicator.height))
            z: activeZone == index ? 1 : 0

            Rectangle {
                property int padding: 2

                anchors.fill: parent
                anchors.margins: padding
                property var ctx: colorHelper.zoneCtx(modelData, indicator.baseIndex + index, indicator.total)
                color: {
                    if (activeZone == index)
                        return colorHelper.pick(config, "miniZoneActive", modelData.color ? colorHelper.tintWithAlpha(colorHelper.buttonColor, modelData.color, 0.6) : colorHelper.accentColor, ctx);
                    else
                        return colorHelper.pick(config, "miniZone", modelData.color ? colorHelper.tintWithAlpha(colorHelper.buttonColor, modelData.color, 0.2) : colorHelper.buttonColor, ctx);
                }
                border.color: colorHelper.pick(config, "miniZoneBorder", colorHelper.getBorderColor(color), ctx)
                border.width: 1
                radius: 5

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }

                }

            }

        }

    }

    Components.ColorHelper {
        id: colorHelper
    }

}
