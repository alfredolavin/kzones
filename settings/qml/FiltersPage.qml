import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.margins: Kirigami.Units.largeSpacing
        QQC2.Label { text: "Mode:" }
        QQC2.ComboBox {
            model: ["Include", "Exclude"]
            currentIndex: app.v.filterMode
            onActivated: index => app.set("filterMode", index)
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Window classes to include or exclude, one per line"
            opacity: 0.8
        }
    }
    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: Kirigami.Units.largeSpacing
        QQC2.TextArea {
            font.family: "monospace"
            text: app.v.filterList
            onTextChanged: if (activeFocus) app.set("filterList", text)
        }
    }
}
