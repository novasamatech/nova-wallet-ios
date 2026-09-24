import Foundation
import SubstrateSdk
import BigInt

extension MultisigPallet {
    static let accountIdPrefix = "modlpy/utilisuba"

    enum AccountIdDerivationError: Error {
        case invalidThreshold
        case invalidSignatories
    }

    static func deriveAccountId(signatories: [AccountId], threshold: Threshold) throws -> AccountId {
        let sortedSignatories = signatories.sorted { $0.lexicographicallyPrecedes($1) }

        guard threshold > 0, Int(threshold) <= sortedSignatories.count else {
            throw AccountIdDerivationError.invalidThreshold
        }

        guard
            sortedSignatories.count < 1 << 30,
            Set(sortedSignatories).count == sortedSignatories.count,
            sortedSignatories.allSatisfy({ $0.count == SubstrateConstants.accountIdLength }) else {
            throw AccountIdDerivationError.invalidSignatories
        }

        let encoder = ScaleEncoder()
        encoder.appendRaw(data: Data(accountIdPrefix.utf8))
        try BigUInt(sortedSignatories.count).encode(scaleEncoder: encoder)
        sortedSignatories.forEach { encoder.appendRaw(data: $0) }
        encoder.appendRaw(data: Data(threshold.littleEndianBytes))

        return try encoder.encode().blake2b32()
    }
}
