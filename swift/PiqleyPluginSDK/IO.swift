import Foundation
import PiqleyCore

/// Internal protocol for writing JSON lines to output.
protocol PluginIO: Sendable {
    func writeLine(_ line: String)
}

/// Writes to stdout with immediate flushing.
struct StdoutIO: PluginIO {
    func writeLine(_ line: String) {
        print(line)
        fflush(stdout)
    }
}

/// Captures output lines for testing.
final class CapturedIO: PluginIO, @unchecked Sendable {
    private let lock = NSLock()
    private var _lines: [String] = []

    func writeLine(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        _lines.append(line)
    }

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _lines
    }
}
