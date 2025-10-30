import Foundation
import BigInt
import Foundation_iOS

class GiftTransferBaseInteractor: OnChainTransferBaseInteractor {
    var pendingFees: [TransactionFeeId: FeeType] = [:]

    let logger = Logger.shared

    func estimateFee(
        for _: OnChainTransferAmount<BigUInt>,
        transactionId _: GiftTransactionFeeId,
        recepientAccountId _: AccountId
    ) {
        fatalError("Method should be overridden")
    }
}

extension GiftTransferBaseInteractor {
    func estimateFee(for amount: OnChainTransferAmount<BigUInt>) {
        let builder = GiftFeeDescriptionBuilder()
        estimateFee(for: amount, feeType: .claimGift(builder))
    }

    func estimateFee(
        for amount: OnChainTransferAmount<BigUInt>,
        feeType: FeeType,
    ) {
        let recepientAccountId = AccountId.zeroAccountId(of: chain.accountIdSize)

        let transactionId = GiftTransactionFeeId(
            recepientAccountId: recepientAccountId,
            amount: amount
        )

        pendingFees[transactionId.rawValue] = feeType

        estimateFee(
            for: amount,
            transactionId: transactionId,
            recepientAccountId: recepientAccountId
        )
    }
}

extension GiftTransferBaseInteractor {
    enum FeeType {
        case createGift(GiftFeeDescriptionBuilder)
        case claimGift(GiftFeeDescriptionBuilder)
    }

    struct GiftTransactionFeeId: Hashable, RawRepresentable {
        let recepientAccountId: AccountId
        let amount: OnChainTransferAmount<BigUInt>

        var rawValue: String {
            [
                String(amount.value),
                recepientAccountId.toHex(),
                amount.name
            ].joined(with: .dash)
        }

        init(
            recepientAccountId: AccountId,
            amount: OnChainTransferAmount<BigUInt>
        ) {
            self.recepientAccountId = recepientAccountId
            self.amount = amount
        }

        init?(rawValue: String) {
            let splitted = rawValue.split(by: .dash)

            guard
                splitted.count == 3,
                let amountValue = BigUInt(splitted[0]),
                let recepientAccountId = try? AccountId(hexString: String(splitted[1]))
            else {
                return nil
            }

            let amountName = String(splitted[2])

            switch amountName {
            case "all":
                amount = .all(value: amountValue)
            case "concrete":
                amount = .concrete(value: amountValue)
            default:
                return nil
            }

            self.recepientAccountId = recepientAccountId
        }
    }
}
