import Testing
@testable import Fingerprinting

@Suite("DCT")
struct DCTTests {
    @Test("1D DCT of uniform input produces DC-only output")
    func uniformInput() {
        let input = [Double](repeating: 1.0, count: 8)
        let result = DCT.dct1D(input)
        #expect(result.count == 8)
        #expect(result[0] > 0.1)
        for i in 1..<8 {
            #expect(abs(result[i]) < 1e-10)
        }
    }

    @Test("2D DCT of 4x4 checkerboard")
    func twoDimensionalDCT() {
        let matrix: [[Double]] = [
            [255, 0, 255, 0],
            [0, 255, 0, 255],
            [255, 0, 255, 0],
            [0, 255, 0, 255],
        ]
        let result = DCT.dct2D(matrix)
        #expect(result.count == 4)
        #expect(result[0].count == 4)
        // DC component is the sum of all elements: 8 * 255 = 2040
        #expect(abs(result[0][0] - 2040.0) < 1e-6)
    }

    @Test("2D DCT output dimensions match input")
    func outputDimensions() {
        let matrix = (0..<32).map { _ in (0..<32).map { _ in Double.random(in: 0...255) } }
        let result = DCT.dct2D(matrix)
        #expect(result.count == 32)
        #expect(result[0].count == 32)
    }
}
