import Foundation

enum SubtensorShieldConstants {
    // MevShield rejects a carrier whose era is immortal or longer than 8 blocks as Stale at pool entry
    static let eraPeriod: UInt64 = 8

    static let signaturesPerOrder = 2

    static let confirmationWindowBlocks = 2 * eraPeriod + 1
}

struct SubtensorShieldQuote {
    let operation: SubtensorOperation
    let innerFee: ExtrinsicFeeProtocol
    let carrierFee: ExtrinsicFeeProtocol

    var totalFee: ExtrinsicFeeProtocol {
        ExtrinsicFee(
            amount: innerFee.amount + carrierFee.amount,
            payer: nil,
            weight: innerFee.weight + carrierFee.weight
        )
    }
}

struct SubtensorSealedInner {
    let carrierNonce: UInt32
    let era: ExtrinsicEraParameters
    let extrinsic: Data
    let extrinsicHash: ExtrinsicHash
    let ciphertext: Data
}

enum SubtensorShieldedSubmission {
    case executed(inner: SubstrateExtrinsicStatus, carrier: SubstrateExtrinsicStatus.SuccessExtrinsic?)
    case notExecuted(carrier: SubstrateExtrinsicStatus.SuccessExtrinsic?)
    case carrierFailed(SubstrateExtrinsicStatus.FailedExtrinsic)
}

enum SubtensorShieldError: Error {
    case keyUnavailable
    case ciphertextTooLong(Int)
    case carrierRejected(Error)
}
