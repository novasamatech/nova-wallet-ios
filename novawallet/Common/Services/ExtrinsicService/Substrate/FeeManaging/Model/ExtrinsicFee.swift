import Foundation
import BigInt

struct ExtrinsicFeePayer: Equatable {
    enum Reason: Equatable {
        case delegate
    }

    let accountId: AccountId?
    let reason: Reason

    init(accountId: AccountId?, reason: Reason) {
        self.accountId = accountId
        self.reason = reason
    }

    init?(senderResolution: ExtrinsicSenderResolution) {
        switch senderResolution {
        case let .delegate(resolvedDelegate):
            accountId = resolvedDelegate.delegateAccount?.chainAccount.accountId
            reason = .delegate
        case .current:
            return nil
        }
    }
}

protocol ExtrinsicFeeProtocol {
    var amount: BigUInt { get }
    var displayAmount: BigUInt { get }
    var payer: ExtrinsicFeePayer? { get }
    var weight: Substrate.Weight { get }
}

extension ExtrinsicFeeProtocol {
    var displayAmount: BigUInt {
        amount
    }

    var amountForCurrentAccount: BigUInt? {
        payer == nil ? amount : nil
    }
}

struct ExtrinsicFee: ExtrinsicFeeProtocol {
    let amount: BigUInt
    let displayAmount: BigUInt
    let payer: ExtrinsicFeePayer?
    let weight: Substrate.Weight

    init?(dispatchInfo: RuntimeDispatchInfo, payer: ExtrinsicFeePayer?) {
        guard let amount = BigUInt(dispatchInfo.fee) else {
            return nil
        }

        self.amount = amount
        displayAmount = amount
        self.payer = payer
        weight = dispatchInfo.weight
    }

    init(amount: BigUInt, payer: ExtrinsicFeePayer?, weight: Substrate.Weight) {
        self.init(amount: amount, displayAmount: amount, payer: payer, weight: weight)
    }

    init(amount: BigUInt, displayAmount: BigUInt, payer: ExtrinsicFeePayer?, weight: Substrate.Weight) {
        self.amount = amount
        self.displayAmount = displayAmount
        self.payer = payer
        self.weight = weight
    }

    static func zero() -> ExtrinsicFee {
        .init(amount: 0, payer: nil, weight: .zero)
    }
}
