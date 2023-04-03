import Foundation

extension String {
    func base64padDecodedData() -> Data? {
        let paddingLength = 4 - count % 4
        let padding = String(repeating: "=", count: paddingLength)
        let base64 = self + padding

        guard let data = Data(base64Encoded: base64) else {
            return nil
        }

        return data
    }
}
