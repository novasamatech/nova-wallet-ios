import Foundation

struct RaiseNonceRequest: Encodable {
    enum CodingKeys: String, CodingKey {
        case type
        case publicKey = "method"
    }

    let type: String
    @HexCodable var publicKey: Data
}

struct RaiseVerificationRequest: Encodable {
    enum CodingKeys: String, CodingKey {
        case action
        case signedNonce = "signed_nonce"
    }

    let action: String
    @HexCodable var signedNonce: Data
}

struct RaiseActionRequest: Encodable {
    enum CodingKeys: String, CodingKey {
        case action
    }

    let action: String
}

// swiftlint:disable identifier_name

struct RaiseCryptoQuoteRequest: Encodable {
    enum CodingKeys: String, CodingKey {
        case from = "from_currency"
        case to = "to_currency"
    }

    let from: String
    let to: String
}

// swiftlint:enable identifier_name
