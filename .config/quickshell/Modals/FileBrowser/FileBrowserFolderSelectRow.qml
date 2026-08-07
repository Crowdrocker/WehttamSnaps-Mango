import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: folderSelectRow

    property bool selectFolderMode: false
    property string currentPath: ""

    signal folderSelected(string folderPath)

    height: selectFolderMode ? 40 : 0
    visible: selectFolderMode
    spacing: Theme.spacingM

    StyledText {
        id: pathDisplay
        width: parent.width - selectButton.width - Theme.spacingM
        height: 40
        text: currentPath.replace("file://", "")
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceText
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideMiddle
        anchors.verticalCenter: parent.verticalCenter
    }

    StyledRect {
        id: selectButton

        width: 80
        height: 40
        color: Theme.primary
        radius: Theme.cornerRadius

        StyledText {
            anchors.centerIn: parent
            text: I18n.tr("Select")
            color: Theme.primaryText
            font.pixelSize: Theme.fontSizeMedium
        }

        StateLayer {
            stateColor: Theme.primary
            cornerRadius: Theme.cornerRadius
            onClicked: {
                var folderPath = currentPath.replace(/^file:\/\//, '');
                folderPath = folderPath.replace(/\/+$/, '');
                if (folderPath) {
                    folderSelected("file://" + folderPath);
                }
            }
        }
    }
}
