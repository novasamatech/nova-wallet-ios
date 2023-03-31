import Foundation

func decodeMultibase(_ input: String) -> Data? {
    // Check if the input starts with a multibase prefix
    guard let prefix = input.first else { return nil }
    let encoding = MultibaseEncoding(rawValue: prefix)
    guard encoding != nil else { return nil }

    // Remove the prefix from the input
    let dataString = String(input.dropFirst())

    // Decode the input using the specified encoding
    guard let data = encoding?.decode(dataString) else { return nil }

    return data
}

enum MultibaseEncoding: Character {
    case base2 = "0"
    case base8 = "7"
    case base10 = "9"
    case base16 = "f"
    case base32hex = "v"
    case base32 = "b"
    case base58flickr = "Z"
    case base64 = "m"
    case base64url = "u"

    func decode(_ input: String) -> Data? {
        switch self {
        case .base2:
            return Data(base2Encoded: input)
        case .base8:
            return Data(base8Encoded: input)
        case .base10:
            return Data(base10Encoded: input)
        case .base16:
            return Data(base16Encoded: input)
        case .base32hex:
            return Data(base32hexEncoded: input)
        case .base32:
            return Data(base32Encoded: input)
        case .base58flickr:
            return Data(base58FlickrEncoded: input)
        case .base64:
            return Data(base64Encoded: input)
        case .base64url:
            return Data(base64UrlEncoded: input)
        }
    }
}
