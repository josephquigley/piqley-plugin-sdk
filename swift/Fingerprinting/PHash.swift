import Foundation

public enum PHash {
    public static func hash(from pixels: [[Double]]) -> ImageFingerprint {
        precondition(pixels.count == 32 && pixels.allSatisfy { $0.count == 32 },
                     "PHash requires a 32x32 pixel matrix")

        let dctResult = DCT.dct2D(pixels)

        var values: [Double] = []
        values.reserveCapacity(63)
        for row in 0..<8 {
            for col in 0..<8 {
                if row == 0 && col == 0 { continue }
                values.append(dctResult[row][col])
            }
        }

        let sorted = values.sorted()
        let median = sorted[sorted.count / 2]

        var hashValue: UInt64 = 0
        var bitIndex = 0
        for row in 0..<8 {
            for col in 0..<8 {
                if row == 0 && col == 0 {
                    bitIndex += 1
                    continue
                }
                if dctResult[row][col] > median {
                    hashValue |= (1 << bitIndex)
                }
                bitIndex += 1
            }
        }

        let hex = String(hashValue, radix: 16, uppercase: false)
        let padded = String(repeating: "0", count: max(0, 16 - hex.count)) + hex
        return ImageFingerprint(hash: padded)
    }
}
