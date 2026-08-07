pragma Singleton
pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    // Supported languages (UI). Empty string = system default / untranslated (fallback to en).
    readonly property var supportedLanguages: [
        "en",
        "de",
        "es",
        "fa",
        "fr",
        "he",
        "hu",
        "it",
        "ja",
        "nl",
        "pl",
        "pt",
        "ru",
        "sv",
        "tr",
        "zh_CN",
        "zh_TW"
    ]

    property string language: (typeof SettingsData !== "undefined" && SettingsData.uiLanguage !== undefined)
                              ? (SettingsData.uiLanguage || "")
                              : ""

    readonly property string effectiveLanguage: {
        const lang = (language || "").trim()
        if (lang.length === 0) return "en"
        return supportedLanguages.includes(lang) ? lang : "en"
    }

    // Normalized shape:
    // {
    //   "<term>": { "<context>": "<translation>" }
    // }
    property var _dict: ({})
    property var _dictEn: ({})

    function _normalize(obj) {
        if (!obj) return ({})

        // Array of records: [{term, context, translation, ...}]
        if (Array.isArray(obj)) {
            var out = ({})
            for (var i = 0; i < obj.length; i++) {
                var it = obj[i]
                if (!it || it.term === undefined || it.term === null) continue
                var term = "" + it.term
                if (term.length === 0) continue
                var ctx = (it.context !== undefined && it.context !== null && ("" + it.context).length > 0) ? ("" + it.context) : term
                var tr = (it.translation !== undefined && it.translation !== null && ("" + it.translation).length > 0) ? ("" + it.translation) : term
                if (!out[term]) out[term] = ({})
                out[term][ctx] = tr
            }
            return out
        }

        // Object: either {term: "translation"} or {term: {ctx: "translation"}}
        if (typeof obj === "object") {
            var out2 = ({})
            for (var k in obj) {
                if (!obj.hasOwnProperty(k)) continue
                var v = obj[k]
                if (typeof v === "string") {
                    out2[k] = ({})
                    out2[k][k] = v
                } else if (v && typeof v === "object") {
                    out2[k] = v
                }
            }
            return out2
        }

        return ({})
    }

    function _parseJson(text) {
        try {
            if (!text || !text.trim()) return ({})
            const obj = JSON.parse(text)
            return root._normalize(obj)
        } catch (e) {
            return ({})
        }
    }

    readonly property string _baseDir: `${StandardPaths.writableLocation(StandardPaths.ConfigLocation)}/quickshell/translations`

    FileView {
        id: enFile
        // Keep `translations/en.json` for tooling, but runtime uses poexports map (term -> ctx -> translation).
        path: `${root._baseDir}/poexports/en.json`
        blockLoading: true
        blockWrites: true
        watchChanges: true
        onLoaded: root._dictEn = root._parseJson(enFile.text())
        onLoadFailed: _ => root._dictEn = ({})
    }

    FileView {
        id: langFile
        path: `${root._baseDir}/poexports/${root.effectiveLanguage}.json`
        blockLoading: true
        blockWrites: true
        watchChanges: true
        onLoaded: root._dict = root._parseJson(langFile.text())
        onLoadFailed: _ => root._dict = ({})
    }

    function tr(term, context) {
        const key = (term === undefined || term === null) ? "" : ("" + term)
        if (key.length === 0) return ""
        const ctx = (context !== undefined && context !== null && ("" + context).length > 0) ? ("" + context) : key
        if (root._dict && root._dict[key] && root._dict[key][ctx] !== undefined) return "" + root._dict[key][ctx]
        if (root._dict && root._dict[key] && root._dict[key][key] !== undefined) return "" + root._dict[key][key]
        if (root._dictEn && root._dictEn[key] && root._dictEn[key][ctx] !== undefined) return "" + root._dictEn[key][ctx]
        if (root._dictEn && root._dictEn[key] && root._dictEn[key][key] !== undefined) return "" + root._dictEn[key][key]
        return key
    }

    function trContext(context, term) {
        return tr(term, context)
    }
}
