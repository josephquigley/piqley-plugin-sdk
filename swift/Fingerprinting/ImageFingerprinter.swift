import Foundation

public protocol ImageFingerprinter: Sendable {
    func fingerprint(of imageURL: URL) throws -> ImageFingerprint
}

public struct FilenameFingerprinter: ImageFingerprinter {
    public init() {}

    public func fingerprint(of imageURL: URL) throws -> ImageFingerprint {
        ImageFingerprint(hash: imageURL.lastPathComponent)
    }
}

#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO

public struct PerceptualFingerprinter: ImageFingerprinter {
    public init() {}

    public func fingerprint(of imageURL: URL) throws -> ImageFingerprint {
        let pixels = try loadGrayscalePixels(from: imageURL, size: 32)
        return PHash.hash(from: pixels)
    }

    private func loadGrayscalePixels(from url: URL, size: Int) throws -> [[Double]] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw FingerprintError.imageDecodeFailed(url.lastPathComponent)
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw FingerprintError.imageDecodeFailed(url.lastPathComponent)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        guard let data = context.data else {
            throw FingerprintError.imageDecodeFailed(url.lastPathComponent)
        }

        let ptr = data.bindMemory(to: UInt8.self, capacity: size * size)
        var pixels: [[Double]] = []
        pixels.reserveCapacity(size)
        for row in 0..<size {
            var rowPixels: [Double] = []
            rowPixels.reserveCapacity(size)
            for col in 0..<size {
                rowPixels.append(Double(ptr[row * size + col]))
            }
            pixels.append(rowPixels)
        }
        return pixels
    }
}
#endif

public enum FingerprintError: Error, LocalizedError {
    case imageDecodeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .imageDecodeFailed(let filename):
            return "Failed to decode image: \(filename)"
        }
    }
}
