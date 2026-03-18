import PiqleyPluginSDK

@main
struct Plugin: PiqleyPlugin {
    func handle(_ request: PluginRequest) async throws -> PluginResponse {
        let images = try request.imageFiles()
        for image in images {
            request.reportProgress("Processing \(image.lastPathComponent)...")
            // TODO: Add your plugin logic here
            request.reportImageResult(image.lastPathComponent, success: true)
        }
        return .ok
    }

    static func main() async {
        await Plugin().run()
    }
}
