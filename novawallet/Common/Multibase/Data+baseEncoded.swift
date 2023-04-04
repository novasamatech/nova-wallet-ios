import Foundation

extension Data {
    init?(multibaseEncoded input: String) {
        // Check if the input starts with a multibase prefix
        guard let prefix = input.first else { return nil }
        let encoding = MultibaseEncoding(rawValue: prefix)
        guard encoding != nil else { return nil }

        // Remove the prefix from the input
        let dataString = String(input.dropFirst())

        // Decode the input using the specified encoding
        guard let data = encoding?.decode(dataString) else { return nil }

        self = data
    }
}
