import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.ScrollView {
    id: page
    contentWidth: availableWidth

    Kirigami.FormLayout {
        width: page.availableWidth

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Performance" }
        QQC2.SpinBox {
            Kirigami.FormData.label: "Polling rate:"
            from: 10; to: 1000; stepSize: 10; editable: true
            value: app.v.pollingRate
            textFromValue: (v) => v + " ms"
            valueFromText: (t) => parseInt(t)
            onValueModified: app.set("pollingRate", value)
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Debugging" }
        QQC2.CheckBox {
            text: "Enable logging"
            checked: app.v.enableDebugLogging
            onToggled: app.set("enableDebugLogging", checked)
        }
        QQC2.CheckBox {
            text: "Enable debug overlay"
            checked: app.v.enableDebugOverlay
            onToggled: app.set("enableDebugOverlay", checked)
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Shortcuts" }
        QQC2.Label { text: "Set them in System Settings › Shortcuts (search for “KZones”)" }
    }
}
