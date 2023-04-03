import Foundation
import BigInt

extension String {
    func base36DecodedData() -> Data? {
        let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let base = BigUInt(charset.count)
        var result = BigUInt(0)
        var power = BigUInt(1)

        for char in uppercased().reversed() {
            guard let index = charset.firstIndex(of: char) else {
                return nil
            }
            result += power * BigUInt(charset.position(index))
            power *= base
        }

        var data = result.serialize()
        while !data.isEmpty, data[0] == 0 {
            data.remove(at: 0)
        }

        return data.isEmpty ? Data([0]) : data
    }
}
