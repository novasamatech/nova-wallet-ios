import Foundation

extension Data {
    init?(base64UrlEncoded input: String) {
        guard let data = Self.decodeBase64Url(input: input, padding: false) else {
            return nil
        }
        self = data
    }

    init?(base64UrlPadEncoded input: String) {
        guard let data = Self.decodeBase64Url(input: input, padding: true) else {
            return nil
        }
        self = data
    }

    static func decodeBase64Url(input: String, padding: Bool) -> Data? {
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

        // replace URL-safe characters
        base64 = base64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")

        return Data(base64Encoded: base64)
    }
}
