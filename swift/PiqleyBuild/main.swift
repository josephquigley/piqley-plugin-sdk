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
} catch {
    var err = StderrStream()
    print("Error: \(error)", to: &err)
    exit(1)
}
