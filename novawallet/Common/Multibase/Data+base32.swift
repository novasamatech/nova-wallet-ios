import Foundation

extension Data {
    init?(base32Encoded input: String) {
        let alphabet = [UInt8]("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)

        guard let data = Self.base32Decode(
            input: input.uppercased(),
            alphabet: alphabet,
            paddingAllowed: false
        ) else {
            return nil
        }

        self = data
    }

    init?(base32padEncoded input: String) {
        let alphabet = [UInt8]("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)

        guard let data = Self.base32Decode(
            input: input.uppercased(),
            alphabet: alphabet,
            paddingAllowed: true
        ) else {
            return nil
        }

        self = data
    }

    init?(base32zEncoded input: String) {
        let alphabet = [UInt8]("ybndrfg8ejkmcpqxot1uwisza345h769".utf8)

        guard let data = Self.base32Decode(
            input: input,
            alphabet: alphabet,
            paddingAllowed: false
        ) else {
            return nil
        }

        self = data
    }

    init?(base32hexEncoded input: String) {
        let alphabet = [UInt8]("0123456789ABCDEFGHIJKLMNOPQRSTUV".utf8)

        guard let data = Self.base32Decode(
            input: input.uppercased(),
            alphabet: alphabet,
            paddingAllowed: false
        ) else {
            return nil
        }

        self = data
    }

    init?(base32hexPadEncoded input: String) {
        let alphabet = [UInt8]("0123456789ABCDEFGHIJKLMNOPQRSTUV".utf8)

        guard let data = Self.base32Decode(
            input: input.uppercased(),
            alphabet: alphabet,
            paddingAllowed: true
        ) else {
            return nil
        }

        self = data
    }

    static func base32Decode(input: String, alphabet: [UInt8], paddingAllowed: Bool) -> Data? {
        let padding: UInt8 = 61
        var bits: UInt64 = 0
        var bitCount: Int = 0
        var bytes = [UInt8]()

        for char in input.utf8 {
            if let index = alphabet.firstIndex(of: char) {
                bits = (bits << 5) | UInt64(index)
                bitCount += 5

                if bitCount >= 8 {
                    let byte = UInt8(truncatingIfNeeded: bits >> UInt64(bitCount - 8))
                    bytes.append(byte)
                    bitCount -= 8
                }
            } else if char == padding, paddingAllowed {
                break
            } else {
                return nil
            }
        }

        guard bitCount <= 5 else { return nil }

        return Data(bytes)
    }
}
