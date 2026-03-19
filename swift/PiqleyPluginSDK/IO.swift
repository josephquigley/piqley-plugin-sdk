import Foundation
import PiqleyCore
import Synchronization

/// Internal protocol for writing JSON lines to output.
protocol PluginIO: Sendable {
    func writeLine(_ line: String)
}

/// Writes to stdout with immediate flushing.
struct StdoutIO: PluginIO {
    func writeLine(_ line: String) {
        var out = FileHandleOutputStream(FileHandle.standardOutput)
        print(line, to: &out)
    }
}

/// A `TextOutputStream` backed by a `FileHandle` that flushes after each write.
private struct FileHandleOutputStream: TextOutputStream {
    private let handle: FileHandle

    init(_ handle: FileHandle) {
        self.handle = handle
    }

    mutating func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            handle.write(data)
        }
    }
}

/// Captures output lines for testing.
final class CapturedIO: PluginIO, Sendable {
    private let _lines = Mutex<[String]>([])

    func writeLine(_ line: String) {
        _lines.withLock { $0.append(line) }
    }

    var lines: [String] {
        _lines.withLock { $0 }
    }
}
