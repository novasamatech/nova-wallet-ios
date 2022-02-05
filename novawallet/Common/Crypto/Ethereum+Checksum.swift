import Foundation
import SubstrateSdk

extension AccountId {
    func toEthereumAddressWithChecksum() -> AccountAddress? {
        let address = toHex()

        guard let addressData = address.data(using: .utf8) else {
            return nil
        }

        guard let hashedAddress = try? addressData.keccak256().toHex() as NSString else {
            return nil
        }

        let digitSet = CharacterSet(charactersIn: "0123456789")
        let alphaSet = CharacterSet(charactersIn: "abcdef")

        let maybeChecksumedAddress: String? = address.unicodeScalars.enumerated().reduce(
            ""
        ) { maybeResult, indexedElement in
            guard let result = maybeResult else {
                return maybeResult
            }

            let character = indexedElement.element

            if digitSet.contains(character) {
                return result + String(character)
            }

            if alphaSet.contains(character) {
                let index = indexedElement.offset
                let nibbleString = hashedAddress.substring(with: NSRange(location: index, length: 1))

                guard let hashedAddressNibble = Int(nibbleString, radix: 16) else {
                    return nil
                }

                if hashedAddressNibble > 7 {
                    return result + String(character).uppercased()
                } else {
                    return result + String(character)
                }
            }

            return nil
        }

        return maybeChecksumedAddress.map { "0x" + $0 }
    }
}

extension AccountAddress {
    func toEthereumAddressWithChecksum() -> AccountAddress? {
        (try? Data(hexString: self))?.toEthereumAddressWithChecksum()
    }

    func isEthereumChecksumValid() -> Bool {
        guard let expectedAddress = try? Data(hexString: self).toEthereumAddressWithChecksum() else {
            return false
        }

        return self == expectedAddress
    }
}
