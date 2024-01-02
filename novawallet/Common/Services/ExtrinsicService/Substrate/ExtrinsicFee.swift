import Foundation
import BigInt

struct ExtrinsicFeePayer: Equatable {
    enum Reason: Equatable {
        case proxy
    }

    let accountId: AccountId
    let reason: Reason

    init(accountId: AccountId, reason: Reason) {
        self.accountId = accountId
        self.reason = reason
    }

    init?(senderResolution: ExtrinsicSenderResolution) {
        switch senderResolution {
        case let .proxy(resolvedProxy):
            accountId = resolvedProxy.proxyAccount.chainAccount.accountId
            reason = .proxy
        case .current:
            return nil
        }
    }
}

protocol ExtrinsicFeeProtocol {
    var amount: BigUInt { get }
    var payer: ExtrinsicFeePayer? { get }
    var weight: BigUInt { get }
}

struct ExtrinsicFee: ExtrinsicFeeProtocol {
    let amount: BigUInt
    let payer: ExtrinsicFeePayer?
    let weight: BigUInt

    init?(dispatchInfo: RuntimeDispatchInfo, payer: ExtrinsicFeePayer?) {
        guard let amount = BigUInt(dispatchInfo.fee) else {
            return nil
        }

        self.amount = amount
        self.payer = payer
        weight = BigUInt(dispatchInfo.weight)
    }

    init(amount: BigUInt, payer: ExtrinsicFeePayer?, weight: BigUInt) {
        self.amount = amount
        self.payer = payer
        self.weight = weight
    }
}
