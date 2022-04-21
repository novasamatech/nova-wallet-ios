import Foundation

extension Data {
    func ethereumPersonalSignMessage() -> Data? {
        let bytesCount = count

        let messagePrefix = "\u{19}Ethereum Signed Message:\n\(String(bytesCount))"

        guard let prefixData = messagePrefix.data(using: .utf8) else {
            return nil
        }

        return prefixData + self
    }
}
