pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var indexedFiles: []
    property int maxResults: 50

    // Directories to search (respect XDG user directories)
    property var searchPaths: {
        const home = Quickshell.env("HOME") || ""
        const xdgDesktop = Quickshell.env("XDG_DESKTOP_DIR") || ""
        const xdgDocuments = Quickshell.env("XDG_DOCUMENTS_DIR") || ""
        const xdgDownload = Quickshell.env("XDG_DOWNLOAD_DIR") || ""
        const xdgMusic = Quickshell.env("XDG_MUSIC_DIR") || ""
        const xdgPictures = Quickshell.env("XDG_PICTURES_DIR") || ""
        const xdgVideos = Quickshell.env("XDG_VIDEOS_DIR") || ""

        const paths = [home]
        if (xdgDesktop && xdgDesktop !== home && xdgDesktop !== "") paths.push(xdgDesktop)
        if (xdgDocuments && xdgDocuments !== home && xdgDocuments !== "") paths.push(xdgDocuments)
        if (xdgDownload && xdgDownload !== home && xdgDownload !== "") paths.push(xdgDownload)
        if (xdgMusic && xdgMusic !== home && xdgMusic !== "") paths.push(xdgMusic)
        if (xdgPictures && xdgPictures !== home && xdgPictures !== "") paths.push(xdgPictures)
        if (xdgVideos && xdgVideos !== home && xdgVideos !== "") paths.push(xdgVideos)
        return paths
    }

    // Hidden file extensions to skip
    property var skipExtensions: [".tmp", ".log", ".cache", ".crswap", ".flatpak", ".pak", ".part", ".crdownload"]

    // Hidden directory names to skip
    property var skipDirectories: [".git", ".cache", ".config", ".local", "node_modules", "target", "build", ".Trash-1000", ".vscode", ".idea"]

    function shouldSkipFile(filePath) {
        const fileName = filePath.split('/').pop() || ""
        if (fileName.startsWith('.')) return true
        const ext = '.' + fileName.split('.').pop()
        return skipExtensions.includes(ext)
    }

    function buildFindCommand(paths, query) {
        const q = query.toLowerCase().trim()
        const findCmd = ["find"]
        for (const p of paths) {
            if (p && p.length > 0) findCmd.push(p)
        }
        findCmd.push("-not", "-path", "*/.*")
        findCmd.push("-not", "-name", ".*")
        for (const skip of skipDirectories) {
            findCmd.push("-not", "-path", "*/" + skip + "/*")
        }
        findCmd.push("-iname", "*" + q + "*")
        findCmd.push("-printf", "%p\t%y\n")
        return findCmd
    }

    function searchFiles(query, callback) {
        if (!query || query.length === 0) {
            callback([])
            return
        }

        const cmd = buildFindCommand(searchPaths, query)

        const proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { stdout: SplitParser {} }',
            root, "fileSearchProc"
        )
        proc.command = cmd
        proc.workingDirectory = Quickshell.env("HOME") || "/"

        var results = []

        proc.stdout.read.connect(function(line) {
            const trimmed = line.trim()
            const parts = trimmed.split('\t')
            if (parts.length === 2 && results.length < maxResults) {
                const path = parts[0]
                const type = parts[1]
                if (!shouldSkipFile(path)) {
                    const fileName = path.split('/').pop() || ""
                    results.push({
                        path: path,
                        name: fileName,
                        isDirectory: type === 'd'
                    })
                }
            }
        })

        proc.exited.connect(function() {
            callback(results)
            proc.destroy()
        })

        proc.running = true
    }
}
