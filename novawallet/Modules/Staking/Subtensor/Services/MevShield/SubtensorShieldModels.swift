import Foundation

enum SubtensorShieldConstants {
    // MevShield rejects a carrier whose era is immortal or longer than 8 blocks as Stale at pool entry
    static let eraPeriod: UInt64 = 8

    // a NextKey read at best block N decrypts only in N + 2, which must stay inside the era born at the finalized head
    static let keyActivationDelay: BlockNumber = 2
    static let maxFinalityLag = BlockNumber(eraPeriod) - 1 - keyActivationDelay

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

struct SubtensorShieldKeyRetry {
    let interval: TimeInterval
}

struct SubtensorSealedInner {
    let carrierNonce: UInt32
    let era: ExtrinsicEraParameters
    let extrinsic: Data
    let extrinsicHash: ExtrinsicHash
    let ciphertext: Data
}

enum SubtensorShieldCarrierLookup {
    case found(SubstrateExtrinsicStatus.SuccessExtrinsic)
    case absent
    case unknown
}

enum SubtensorShieldedSubmission {
    case executed(inner: SubstrateExtrinsicStatus, carrier: SubtensorShieldCarrierLookup)
    case notExecuted(carrier: SubtensorShieldCarrierLookup, rejection: Error?)
}

enum SubtensorShieldError: Error {
    case keyUnavailable
    case fundsShort
    case quoteUnavailable
    case notReady
    case ciphertextTooLong(Int)
    case finalityLag(BlockNumber)
}
