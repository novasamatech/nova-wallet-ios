import Foundation

extension Data {
    func base64URLDecoded() -> Data? {
        guard let string = String(data: self, encoding: .utf8) else {
            return nil
        }
        // Replace the URL-safe characters in the Base64URL-encoded string with the corresponding Base64 characters
        let base64String = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")

        // Add padding characters if necessary
        let paddingLength = 4 - base64String.count % 4
        let paddedString = base64String + String(repeating: "=", count: paddingLength)

        // Convert the padded Base64 string to a byte array
        guard let byteArray = Data(base64Encoded: paddedString) else {
            return nil
        }

        // Return the decoded data
        return byteArray
    }
}

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
