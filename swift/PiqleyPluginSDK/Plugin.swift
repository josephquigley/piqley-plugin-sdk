import Foundation
import PiqleyCore

// MARK: - PiqleyPlugin

public protocol PiqleyPlugin: Sendable {
    func handle(_ request: PluginRequest) async throws -> PluginResponse
}

extension PiqleyPlugin {

    /// Call from `@main static func main() async`.
    public func run() async {
        let inputData = FileHandle.standardInput.readDataToEndOfFile()
        let exitCode = await run(input: inputData, io: StdoutIO())
        exit(Int32(exitCode))
    }

    /// Internal testable entry point.
    func run(input: Data, io: PluginIO) async -> Int {
        // 1. Decode payload
        let payload: PluginInputPayload
        do {
            payload = try JSONDecoder().decode(PluginInputPayload.self, from: input)
        } catch {
            writeError("Failed to decode plugin payload: \(error)", io: io)
            return 1
        }

        // 2. Build request
        let request = PluginRequest(payload: payload, io: io)

        // 3. Call handle()
        let response: PluginResponse
        do {
            response = try await handle(request)
        } catch {
            writeError(error.localizedDescription, io: io)
            return 1
        }

        // 4. Write result line
        writeOutputLine(response.toOutputLine(), io: io)

        // 5. Return appropriate exit code
        return response.success ? 0 : 1
    }

    // MARK: - Private helpers

    private func writeError(_ message: String, io: PluginIO) {
        let line = PluginOutputLine(type: "result", success: false, error: message)
        writeOutputLine(line, io: io)
    }

    private func writeOutputLine(_ line: PluginOutputLine, io: PluginIO) {
        if let data = try? JSONEncoder().encode(line), let string = String(data: data, encoding: .utf8) {
            io.writeLine(string)
        }
    }
}
