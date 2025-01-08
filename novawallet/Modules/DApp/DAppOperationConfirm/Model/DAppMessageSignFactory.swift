import Foundation
import SubstrateSdk

protocol DAppMessageSignFactoryProtocol {
    func serializeSigningMessage(from message: JSON) throws -> Data
}

final class PolkadotExtensionMessageSignFactory: DAppMessageSignFactoryProtocol {
    private func serializeMessage(from message: JSON) throws -> Data {
        if case let .stringValue(stringValue) = message {
            if stringValue.isHex() {
                return try Data(hexString: stringValue)
            } else {
                guard let data = stringValue.data(using: .utf8) else {
                    throw CommonError.dataCorruption
                }

                return data
            }

        } else {
            throw CommonError.dataCorruption
        }
    }

    private func wrappingMessageIfNeeded(_ message: Data) throws -> Data {
        let prefix = "<Bytes>"
        let suffix = "</Bytes>"

        guard let suffixData = suffix.data(using: .ascii), let prefixData = prefix.data(using: .ascii) else {
            throw CommonError.dataCorruption
        }

        if
            message.prefix(prefixData.count) == prefixData,
            message.suffix(suffixData.count) == suffixData {
            return message
        }

        return prefixData + message + suffixData
    }

    func serializeSigningMessage(from message: JSON) throws -> Data {
        let serializedMessage = try serializeMessage(from: message)
        let wrappedMessage = try wrappingMessageIfNeeded(serializedMessage)

        return wrappedMessage
    }
}
