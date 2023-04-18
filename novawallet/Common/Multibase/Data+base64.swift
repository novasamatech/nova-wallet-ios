import Foundation

extension Data {
    init?(base64Encoded input: String, padding: Bool) {
        var base64 = input

        if padding {
            // add padding if necessary
            let paddingLength = base64.count % 4
            if paddingLength > 0 {
                base64 += String(repeating: "=", count: 4 - paddingLength)
            }
        } else {
            // remove padding if necessary
            while base64.count % 4 != 0 {
                base64 += "="
            }
        }

        guard let data = Data(base64Encoded: base64) else {
            return nil
        }

        self = data
    }
}
