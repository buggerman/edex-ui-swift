import Foundation

// Mirrors src-tauri/src/file/main.rs
// Tracks the CWD of the active terminal shell (via lsof, same method as macOS Rust code)
// then watches that directory for changes with FSEvents

@MainActor
final class FileWatcher: ObservableObject {
    @Published var entries: [FileEntry] = []
    @Published var currentPath: String = NSHomeDirectory()

    var showHidden = false {
        didSet { loadDirectory(path: currentPath) }
    }

    private var eventStream: FSEventStreamRef?
    private var watchedPath: String = ""
    private var shellPID: pid_t = 0

    // Called by TerminalPanel when CWD changes via OSC 7 or manual tracking
    func updateCWD(_ path: String) {
        guard path != currentPath else { return }
        currentPath = path
        loadDirectory(path: path)
        watchDirectory(path: path)
    }

    func setPID(_ pid: pid_t) {
        shellPID = pid
    }

    // MARK: - Directory Loading
    // Mirrors file sorting in Rust: directories first, hidden sorted first within category, then alpha

    func loadDirectory(path: String) {
        let url = URL(fileURLWithPath: path)
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        ) else { return }

        var dirEntries: [FileEntry] = []
        var fileEntries: [FileEntry] = []

        for itemURL in items {
            let name = itemURL.lastPathComponent
            let isHidden = name.hasPrefix(".")
            guard showHidden || !isHidden else { continue }

            let rsrc = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let isDir  = rsrc?.isDirectory  ?? false
            let isLink = rsrc?.isSymbolicLink ?? false

            let kind: FileEntryKind = isLink ? .symlink : (isDir ? .directory : .file)
            let entry = FileEntry(id: itemURL.path, name: name, kind: kind,
                                  isHidden: isHidden, path: itemURL.path)
            if isDir { dirEntries.append(entry) } else { fileEntries.append(entry) }
        }

        dirEntries.sort  { ($0.isHidden ? 0 : 1, $0.name) < ($1.isHidden ? 0 : 1, $1.name) }
        fileEntries.sort { ($0.isHidden ? 0 : 1, $0.name) < ($1.isHidden ? 0 : 1, $1.name) }

        // ".." backward tile + settings gear, then dirs, then files
        var all: [FileEntry] = [
            FileEntry(id: "__back__",     name: "..", kind: .backward,  isHidden: false, path: url.deletingLastPathComponent().path),
            FileEntry(id: "__settings__", name: "",   kind: .settings,  isHidden: false, path: ""),
        ]
        all.append(contentsOf: dirEntries)
        all.append(contentsOf: fileEntries)
        entries = all
    }

    // MARK: - FSEvents Watcher

    private func watchDirectory(path: String) {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
        guard path != watchedPath else { return }
        watchedPath = path

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            Task { @MainActor in watcher.loadDirectory(path: watcher.currentPath) }
        }
        let stream = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )
        guard let stream else { return }
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        eventStream = stream
    }
}
