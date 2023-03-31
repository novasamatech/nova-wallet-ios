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
    func base64URLDecodedData() -> Data? {
        var base64URLString = replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if necessary
        let paddingLength = 4 - base64URLString.count % 4
        if paddingLength < 4 {
            base64URLString += String(repeating: "=", count: paddingLength)
        }

        guard let data = Data(base64Encoded: base64URLString) else {
            return nil
        }

        return data
    }
}
