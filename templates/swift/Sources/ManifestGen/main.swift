import Foundation
import PluginHooks

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("Usage: piqley-manifest-gen <output-directory>\n".utf8))
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
try pluginRegistry.writeStageFiles(to: outputDir)
try pluginConfig.writeConfigEntries(to: outputDir)
