import Foundation

enum FileEntryKind {
    case directory
    case file
    case symlink
    case backward   // ".." navigation
    case settings   // gear icon tile
}

struct FileEntry: Identifiable, Equatable {
    let id: String      // full path
    var name: String
    var kind: FileEntryKind
    var isHidden: Bool
    var path: String
}
