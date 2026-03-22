import Foundation

// Mirrors src-tauri/src/file/main.rs
// CWD tracking: polls lsof every 2 s (same technique as the macOS Rust path),
// and also handles OSC 7 callbacks from SwiftTerm if the shell emits them.

@MainActor
final class FileWatcher: ObservableObject {
    @Published var entries:     [FileEntry] = []
    @Published var currentPath: String = NSHomeDirectory()

    var showHidden = false { didSet { loadDirectory(path: currentPath) } }

    // Set by TerminalPanel so FileSystemPanel can send `cd` commands to the active terminal
    var sendToTerminal: ((String) -> Void)?

    private var eventStream:  FSEventStreamRef?
    private var watchedPath:  String = ""
    private var shellPID:     pid_t = 0
    private var pollTimer:    Timer?

    // MARK: - Public interface

    /// Called by TerminalSessionView once the shell process is running
    func setPID(_ pid: pid_t) {
        shellPID = pid
        startCWDPolling()
    }

    /// Called immediately when OSC 7 arrives from the shell (if the shell supports it)
    func updateCWD(_ path: String) {
        let clean = path.hasPrefix("file://")
            ? URL(string: path)?.path ?? path
            : path
        guard clean != currentPath else { return }
        currentPath = clean
        loadDirectory(path: clean)
        watchDirectory(path: clean)
    }

    // MARK: - Directory loading
    // Sort order mirrors Rust: dirs first, hidden first within category, then alpha

    func loadDirectory(path: String) {
        let url = URL(fileURLWithPath: path)
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        ) else { return }

        var dirs: [FileEntry] = []
        var files: [FileEntry] = []

        for item in items {
            let name     = item.lastPathComponent
            let isHidden = name.hasPrefix(".")
            guard showHidden || !isHidden else { continue }
            let rsrc  = try? item.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let isDir  = rsrc?.isDirectory   ?? false
            let isLink = rsrc?.isSymbolicLink ?? false
            let kind: FileEntryKind = isLink ? .symlink : (isDir ? .directory : .file)
            let entry = FileEntry(id: item.path, name: name, kind: kind,
                                  isHidden: isHidden, path: item.path)
            if isDir { dirs.append(entry) } else { files.append(entry) }
        }

        dirs.sort  { ($0.isHidden ? 0 : 1, $0.name) < ($1.isHidden ? 0 : 1, $1.name) }
        files.sort { ($0.isHidden ? 0 : 1, $0.name) < ($1.isHidden ? 0 : 1, $1.name) }

        var all: [FileEntry] = [
            FileEntry(id: "__back__",     name: "..", kind: .backward, isHidden: false,
                      path: url.deletingLastPathComponent().path),
            FileEntry(id: "__settings__", name: "",   kind: .settings, isHidden: false, path: ""),
        ]
        all.append(contentsOf: dirs)
        all.append(contentsOf: files)
        entries = all
    }

    // MARK: - lsof CWD polling
    // Mirrors src-tauri/src/file/main.rs macOS CWD detection

    private func startCWDPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.pollCWD() }
        }
        // First poll immediately
        Task { await pollCWD() }
    }

    private func pollCWD() async {
        guard shellPID > 0 else { return }
        let pid  = shellPID
        let path = await Task.detached(priority: .utility) { () -> String? in
            FileWatcher.cwdFromLSOF(pid: pid)
        }.value
        if let path { updateCWD(path) }
    }

    // nonisolated so it can be called from a detached task without hopping to MainActor
    private nonisolated static func cwdFromLSOF(pid: pid_t) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        proc.arguments     = ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // lsof -Fn output: line starting with "n" contains the path
        return out.components(separatedBy: "\n")
                  .first { $0.hasPrefix("n") }
                  .map   { String($0.dropFirst()) }
    }

    // MARK: - FSEvents watcher

    private func watchDirectory(path: String) {
        if let s = eventStream {
            FSEventStreamStop(s); FSEventStreamInvalidate(s); FSEventStreamRelease(s)
            eventStream = nil
        }
        guard path != watchedPath else { return }
        watchedPath = path

        var ctx = FSEventStreamContext(version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil)

        let cb: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let w = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            Task { @MainActor in w.loadDirectory(path: w.currentPath) }
        }
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault, cb, &ctx, [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        eventStream = stream
    }
}
