import Foundation

enum MultibaseEncoding: Character {
    case base2 = "0"
    case base8 = "7"
    case base10 = "9"
    case base16 = "f"
    case base16upper = "F"
    case base32hex = "v"
    case base32hexUpper = "V"
    case base32hexPad = "t"
    case base32hexPadUpper = "T"
    case base32 = "b"
    case base32upper = "B"
    case base32pad = "c"
    case base32padUpper = "C"
    case base32z = "h"
    case base36 = "k"
    case base36upper = "K"
    case base58btc = "z"
    case base58flickr = "Z"
    case base64 = "m"
    case base64pad = "M"
    case base64url = "u"
    case base64urlPad = "U"
    case proquint = "p"

    // swiftlint:disable:next cyclomatic_complexity
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
            return Data(base64Encoded: input, padding: false)
        case .base64url:
            return Data(base64UrlEncoded: input)
        case .base16upper:
            return Data(base16Encoded: input)
        case .base32hexUpper:
            return Data(base32hexEncoded: input)
        case .base32hexPad:
            return Data(base32hexPadEncoded: input)
        case .base32hexPadUpper:
            return Data(base32hexPadEncoded: input)
        case .base32upper:
            return Data(base32Encoded: input)
        case .base32pad:
            return Data(base32padEncoded: input)
        case .base32padUpper:
            return Data(base32padEncoded: input)
        case .base32z:
            return Data(base32zEncoded: input)
        case .base36:
            return Data(base36Encoded: input)
        case .base36upper:
            return Data(base36Encoded: input)
        case .base58btc:
            return Data(base58btcEncoded: input)
        case .base64pad:
            return Data(base64Encoded: input, padding: true)
        case .base64urlPad:
            return Data(base64UrlPadEncoded: input)
        case .proquint:
            return Data(proquint: input)
        }
    }
}
