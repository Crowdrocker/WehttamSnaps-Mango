pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import Quickshell
Singleton {
    id: root

    readonly property string weatherApiUrl: Quickshell.env("QUICKSHELL_WEATHER_API_URL") || 
                                           "https://api.open-meteo.com/v1/forecast"
    readonly property string geocodingApiUrl: Quickshell.env("QUICKSHELL_GEOCODING_API_URL") || 
                                             "https://geocoding-api.open-meteo.com/v1/search"
    readonly property string reverseGeocodingApiUrl: Quickshell.env("QUICKSHELL_REVERSE_GEOCODING_API_URL") || 
                                                    "https://nominatim.openstreetmap.org/reverse"
    readonly property string ipLocationApiUrl: Quickshell.env("QUICKSHELL_IP_LOCATION_API_URL") || 
                                              "http://ip-api.com/json/"

    readonly property int networkTimeout: parseInt(Quickshell.env("QUICKSHELL_NETWORK_TIMEOUT") || "10")
    readonly property int networkConnectTimeout: parseInt(Quickshell.env("QUICKSHELL_NETWORK_CONNECT_TIMEOUT") || "5")
    readonly property int networkRetryAttempts: parseInt(Quickshell.env("QUICKSHELL_NETWORK_RETRY_ATTEMPTS") || "3")
    readonly property int networkRetryDelay: parseInt(Quickshell.env("QUICKSHELL_NETWORK_RETRY_DELAY") || "30000")

    readonly property int processTimeout: parseInt(Quickshell.env("QUICKSHELL_PROCESS_TIMEOUT") || "10000")
    readonly property int processDefaultDebounce: parseInt(Quickshell.env("QUICKSHELL_PROCESS_DEBOUNCE") || "50")

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("QUICKSHELL_CONFIG_DIR") || (homeDir ? homeDir + "/.config/quickshell" : "")
    readonly property string cacheDir: Quickshell.env("QUICKSHELL_CACHE_DIR") || (homeDir ? homeDir + "/.cache/quickshell" : "")
    readonly property string stateDir: Quickshell.env("QUICKSHELL_STATE_DIR") || (homeDir ? homeDir + "/.local/state/quickshell" : "")
    readonly property string dataDir: Quickshell.env("QUICKSHELL_DATA_DIR") || (homeDir ? homeDir + "/.local/share/quickshell" : "")

    readonly property string vpnSocketPath: Quickshell.env("EH_SOCKET") || ""
    readonly property bool vpnSingleActive: Quickshell.env("QUICKSHELL_VPN_SINGLE_ACTIVE") === "1"

    readonly property int weatherUpdateInterval: parseInt(Quickshell.env("QUICKSHELL_WEATHER_UPDATE_INTERVAL") || "900000")
    readonly property int weatherMinFetchInterval: parseInt(Quickshell.env("QUICKSHELL_WEATHER_MIN_FETCH_INTERVAL") || "30000")
    readonly property int weatherMaxRetries: parseInt(Quickshell.env("QUICKSHELL_WEATHER_MAX_RETRIES") || "3")
    readonly property int weatherRetryDelay: parseInt(Quickshell.env("QUICKSHELL_WEATHER_RETRY_DELAY") || "30000")

    readonly property int maxPathLength: parseInt(Quickshell.env("QUICKSHELL_MAX_PATH_LENGTH") || "4096")
    readonly property int maxCommandLength: parseInt(Quickshell.env("QUICKSHELL_MAX_COMMAND_LENGTH") || "8192")
    readonly property bool enableCommandValidation: Quickshell.env("QUICKSHELL_DISABLE_COMMAND_VALIDATION") !== "1"

    readonly property bool enablePerformanceMonitoring: Quickshell.env("QUICKSHELL_ENABLE_PERF_MONITORING") === "1"
    readonly property int slowOperationThreshold: parseInt(Quickshell.env("QUICKSHELL_SLOW_OP_THRESHOLD") || "1000")

    function get(key, defaultValue) {
        const envValue = Quickshell.env(key)
        if (envValue !== undefined && envValue !== "") {
            return envValue
        }
        return defaultValue
    }

    function getInt(key, defaultValue) {
        const value = get(key, defaultValue.toString())
        const parsed = parseInt(value)
        return isNaN(parsed) ? defaultValue : parsed
    }

    function getBool(key, defaultValue) {
        const value = get(key, defaultValue ? "1" : "0")
        return value === "1" || value === "true" || value === "yes"
    }

    function validate() {
        const errors = []

        if (networkTimeout <= 0) {
            errors.push("QUICKSHELL_NETWORK_TIMEOUT must be positive")
        }

        if (networkRetryAttempts < 0) {
            errors.push("QUICKSHELL_NETWORK_RETRY_ATTEMPTS must be non-negative")
        }

        if (maxPathLength <= 0) {
            errors.push("QUICKSHELL_MAX_PATH_LENGTH must be positive")
        }

        return {
            valid: errors.length === 0,
            errors: errors
        }
    }
}

