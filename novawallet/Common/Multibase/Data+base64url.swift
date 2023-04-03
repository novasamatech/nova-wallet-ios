import Foundation

extension String {
    func base64URLDecodedData(withPadding padding: Bool = true) -> Data? {
        var base64 = self
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

        // replace URL-safe characters
        base64 = base64.replacingOccurrences(of: "-", with: "+")
        base64 = base64.replacingOccurrences(of: "_", with: "/")

        return Data(base64Encoded: base64)
    }
}
