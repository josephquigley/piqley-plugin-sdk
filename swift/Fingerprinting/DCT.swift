import Foundation

public enum DCT {
    public static func dct1D(_ input: [Double]) -> [Double] {
        let n = input.count
        let nDouble = Double(n)
        return (0..<n).map { k in
            var sum = 0.0
            for i in 0..<n {
                sum += input[i] * cos(Double.pi * Double(k) * (Double(i) + 0.5) / nDouble)
            }
            return sum
        }
    }

    public static func dct2D(_ matrix: [[Double]]) -> [[Double]] {
        let rows = matrix.count
        guard rows > 0 else { return [] }
        let cols = matrix[0].count

        let rowTransformed = matrix.map { dct1D($0) }

        var result = [[Double]](repeating: [Double](repeating: 0.0, count: cols), count: rows)
        for j in 0..<cols {
            let column = (0..<rows).map { rowTransformed[$0][j] }
            let transformed = dct1D(column)
            for i in 0..<rows {
                result[i][j] = transformed[i]
            }
        }

        return result
    }
}
