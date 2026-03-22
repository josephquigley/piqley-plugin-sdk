import Foundation
import PiqleyPluginSDK

struct StderrStream: TextOutputStream {
    mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}

let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
do {
    let outputURL = try Packager.package(directory: directory)
    print("\u{2713} Built \(outputURL.lastPathComponent)")
    print("")
    print("Install with:")
    print("  piqley plugin install \(outputURL.path)")
} catch let error as DecodingError {
    var err = StderrStream()
    print("Error: \(formatDecodingError(error))", to: &err)
    exit(1)
} catch {
    var err = StderrStream()
    print("Error: \(error)", to: &err)
    exit(1)
}

func formatDecodingError(_ error: DecodingError) -> String {
    switch error {
    case let .keyNotFound(key, context):
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        let location = path.isEmpty ? "piqley-build-manifest.json" : path
        return "Missing required field '\(key.stringValue)' in \(location)"
    case let .typeMismatch(type, context):
        let field = context.codingPath.last?.stringValue ?? "unknown"
        return "Invalid type for '\(field)': expected \(type)"
    case let .valueNotFound(type, context):
        let field = context.codingPath.last?.stringValue ?? "unknown"
        return "Missing value for '\(field)': expected \(type)"
    case let .dataCorrupted(context):
        return "Invalid JSON in piqley-build-manifest.json: \(context.debugDescription)"
    @unknown default:
        return "\(error)"
    }
}
