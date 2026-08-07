pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: modalManager

    signal closeAllModalsExcept(var excludedModal)
    signal openSettingsRequested()

    function openModal(modal) {
        if (modal && !modal.allowStacking) {
            closeAllModalsExcept(modal)
        }
    }
}
