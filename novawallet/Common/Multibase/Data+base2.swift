import Foundation

extension Data {
    init?(base2Encoded input: String) {
        guard let decodedData = input.base2DecodedData() else {
            return nil
        }
        self = decodedData
    }

    init?(base8Encoded input: String) {
        guard let decodedData = input.base8DecodedData() else {
            return nil
        }
        self = decodedData
    }

    init?(base10Encoded input: String) {
        guard let decodedData = input.base10DecodedData() else {
            return nil
        }
        self = decodedData
    }

    init?(base16Encoded input: String) {
        guard let decodedData = input.base16DecodedData() else {
            return nil
        }
        self = decodedData
    }

    init?(base32hexEncoded input: String) {
        guard let decodedData = input.base32hexDecodedData() else {
            return nil
        }
        self = decodedData
    }

    init?(base32Encoded input: String) {
        guard let decodedData = input.base32DecodedData() else {
            return nil
        }
        self = decodedData
    }

    init?(base58FlickrEncoded input: String) {
        guard let decodedData = input.base58FlickrDecodedData() else {
            return nil
        }
        self = decodedData
    }

    init?(base64UrlEncoded input: String) {
        guard let decodedData = input.base64URLDecodedData() else {
            return nil
        }
        self = decodedData
    }
}

extension String {
    func base2DecodedData() -> Data? {
        guard count % 8 == 0 else {
            return nil
        }

        var bytes = [UInt8]()

        var index = startIndex
        while index < endIndex {
            let substring = self[index ..< self.index(index, offsetBy: 8)]
            guard let byte = UInt8(substring, radix: 2) else {
                return nil
            }
            bytes.append(byte)
            index = self.index(index, offsetBy: 8)
        }

        return Data(bytes)
    }
}
