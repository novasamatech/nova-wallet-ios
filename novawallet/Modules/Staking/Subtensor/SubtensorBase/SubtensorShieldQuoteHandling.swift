import Foundation

protocol SubtensorShieldQuoteHandling: AnyObject {
    var shieldQuote: SubtensorShieldQuote? { get set }
    var shieldQuoteOperation: SubtensorOperation? { get set }
    var isShieldQuoteResolved: Bool { get set }
    var isShieldQuoteFallback: Bool { get set }
    var fee: ExtrinsicFeeProtocol? { get }
    var transferable: Balance? { get }
    var existentialDeposit: Balance? { get }
    var isRoot: Bool { get }
    var shieldWalletType: MetaAccountModelType { get }
    var shieldInteractor: SubtensorBaseInteractorInputProtocol { get }
    var activeShieldQuote: SubtensorShieldQuote? { get }
    var waitsForShieldQuote: Bool { get }
    var isShieldQuotePending: Bool { get }

    func applyShieldQuoteChange()
    func applyShieldQuoteFallback()
}

extension SubtensorShieldQuoteHandling {
    var eligibleShieldQuote: SubtensorShieldQuote? {
        let input = SubtensorShieldEligibilityInput(
            walletType: shieldWalletType,
            quote: shieldQuote,
            transferable: transferable,
            existentialDeposit: existentialDeposit
        )

        return SubtensorShieldEligibility.isEligible(input) ? shieldQuote : nil
    }

    var isShieldable: Bool {
        !isRoot && SubtensorShieldEligibility.supports(walletType: shieldWalletType)
    }

    var carriesShieldQuoteFallback: Bool {
        isShieldable && isShieldQuoteFallback
    }

    var activeShieldQuote: SubtensorShieldQuote? { eligibleShieldQuote }

    var waitsForShieldQuote: Bool { isShieldable }

    var isShieldQuotePending: Bool { !isShieldQuoteResolved }

    var networkFee: ExtrinsicFeeProtocol? {
        guard waitsForShieldQuote else {
            return fee
        }

        guard !isShieldQuotePending else {
            return nil
        }

        return activeShieldQuote?.totalFee ?? fee
    }

    func applyShieldQuoteFallback() {
        applyShieldQuoteChange()
    }

    func requestShieldQuote(for operation: SubtensorOperation) {
        if operation != shieldQuoteOperation {
            isShieldQuoteResolved = false
        }

        shieldQuoteOperation = operation
        shieldInteractor.estimateShieldQuote(for: operation)
    }

    func resetShieldQuote() {
        shieldQuote = nil
        shieldQuoteOperation = nil
        isShieldQuoteResolved = false
        isShieldQuoteFallback = false
        shieldInteractor.cancelShieldQuote()
    }

    func retryUnresolvedShieldQuote() {
        guard !isShieldQuoteResolved, let shieldQuoteOperation else {
            return
        }

        shieldInteractor.estimateShieldQuote(for: shieldQuoteOperation)
    }

    func didReceiveShieldQuote(_ quote: SubtensorShieldQuote?, for operation: SubtensorOperation) {
        guard operation == shieldQuoteOperation else {
            return
        }

        shieldQuote = quote
        isShieldQuoteResolved = true
        isShieldQuoteFallback = false

        applyShieldQuoteChange()
    }

    func didReceiveShieldQuoteFallback(for operation: SubtensorOperation) {
        guard operation == shieldQuoteOperation else {
            return
        }

        shieldQuote = nil
        isShieldQuoteResolved = true
        isShieldQuoteFallback = true

        applyShieldQuoteFallback()
    }
}
