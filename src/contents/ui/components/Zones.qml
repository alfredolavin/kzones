import QtQuick
import QtQuick.Layouts
import "../components" as Components

Item {
    id: zones

    property var config
    property int currentLayout
    property int highlightedZone
    property int layoutIndex
    property alias repeater: repeater

    Repeater {
        id: repeater

        model: config.layouts[layoutIndex].zones

        // zone
        Item {
            id: zone

            property int zoneIndex: index
            property int zonePadding: config.layouts[layoutIndex].padding || 0
            property var renderZones: config.zoneOverlayIndicatorDisplay == 1 ? [config.layouts[layoutIndex].zones[index]] : config.layouts[layoutIndex].zones
            property int activeIndex: config.zoneOverlayIndicatorDisplay == 1 ? 0 : index
            property var indicatorPos: (modelData && modelData.indicator && modelData.indicator.position) || "center"
            property var cfg: zones.config
            property var zoneCtx: colorHelper.zoneCtx(modelData, index, config.layouts[layoutIndex].zones.length)
            property bool active: (highlightedZone == zoneIndex && currentLayout == layoutIndex)

            x: ((modelData.x / 100) * (clientArea.width - zonePadding)) + zonePadding
            y: ((modelData.y / 100) * (clientArea.height - zonePadding)) + zonePadding
            implicitWidth: ((modelData.width / 100) * (clientArea.width - zonePadding)) - zonePadding
            implicitHeight: ((modelData.height / 100) * (clientArea.height - zonePadding)) - zonePadding

            // zone indicator
            Rectangle {
                id: zoneIndicator

                width: 160
                height: 100
                color: colorHelper.pick(config, "indicatorBackground", colorHelper.backgroundColor, zoneCtx)
                radius: 10
                border.color: colorHelper.pick(config, "indicatorBorder", colorHelper.getBorderColor(color), zoneCtx)
                border.width: 1
                opacity: !showZoneOverlay ? 0 : (zoneSelector.expanded) ? 0 : (active ? 0.6 : 1)
                scale: active ? 1.1 : 1
                visible: config.enableZoneOverlay
                // position
                anchors.left: (indicatorPos === "top-left" || indicatorPos === "left-center" || indicatorPos === "bottom-left") ? parent.left : undefined
                anchors.right: (indicatorPos === "top-right" || indicatorPos === "right-center" || indicatorPos === "bottom-right") ? parent.right : undefined
                anchors.top: (indicatorPos === "top-left" || indicatorPos === "top-center" || indicatorPos === "top-right") ? parent.top : undefined
                anchors.bottom: (indicatorPos === "bottom-left" || indicatorPos === "bottom-center" || indicatorPos === "bottom-right") ? parent.bottom : undefined
                anchors.horizontalCenter: (indicatorPos === "center" || indicatorPos === "top-center" || indicatorPos === "bottom-center") ? parent.horizontalCenter : undefined
                anchors.verticalCenter: (indicatorPos === "center" || indicatorPos === "left-center" || indicatorPos === "right-center") ? parent.verticalCenter : undefined
                // margin
                anchors.leftMargin: (modelData && modelData.indicator && modelData.indicator.margin && modelData.indicator.margin.left) || 0
                anchors.rightMargin: (modelData && modelData.indicator && modelData.indicator.margin && modelData.indicator.margin.right) || 0
                anchors.topMargin: (modelData && modelData.indicator && modelData.indicator.margin && modelData.indicator.margin.top) || 0
                anchors.bottomMargin: (modelData && modelData.indicator && modelData.indicator.margin && modelData.indicator.margin.bottom) || 0
                // offset
                anchors.horizontalCenterOffset: ((modelData && modelData.indicator && modelData.indicator.margin && modelData.indicator.margin.left) || 0) - ((modelData && modelData.indicator && modelData.indicator.margin && modelData.indicator.margin.right) || 0)
                anchors.verticalCenterOffset: ((modelData && modelData.indicator && modelData.indicator.margin && modelData.indicator.margin.top) || 0) - ((modelData && modelData.indicator && modelData.indicator.margin && modelData.indicator.margin.bottom) || 0)

                Components.Indicator {
                    zones: renderZones
                    config: zone.cfg
                    baseIndex: config.zoneOverlayIndicatorDisplay == 1 ? zoneIndex : 0
                    total: config.layouts[layoutIndex].zones.length
                    activeZone: activeIndex
                    anchors.centerIn: parent
                    width: parent.width - 20
                    height: parent.height - 20
                    hovering: (active)
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: zoneSelector.expanded ? 0 : 150
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }

                }

            }

            // zone border
            Rectangle {
                id: zoneBorder

                anchors.fill: parent
                color: "transparent"
                border.color: (active) ? colorHelper.pick(config, "highlightBorder", modelData.color || colorHelper.accentColor, zoneCtx) : "transparent"
                border.width: 3
                radius: 8
            }

            // zone background
            Rectangle {
                id: zoneBackground

                opacity: (highlightedZone == zoneIndex) ? 0.1 : 0
                anchors.fill: parent
                color: colorHelper.pick(config, "highlightFill", modelData.color || colorHelper.accentColor, zoneCtx)
                radius: 8
            }

            // indicator shadow
            Components.Shadow {
                target: zoneIndicator
                config: zone.cfg
                visible: zoneIndicator.visible
            }

            Components.ColorHelper {
                id: colorHelper
            }

        }

    }

}
