import Foundation

final class SwapBasePresenter {
    let logger: LoggerProtocol
    let selectedWallet: MetaAccountModel

    private(set) var balances: [ChainAssetId: AssetBalance] = [:]

    var payAssetBalance: AssetBalance? {
        payChainAsset.flatMap { balances[$0.chainAssetId] }
    }

    var feeAssetBalance: AssetBalance? {
        feeChainAsset.flatMap { balances[$0.chainAssetId] }
    }

    var receiveAssetBalance: AssetBalance? {
        receiveChainAsset.flatMap { balances[$0.chainAssetId] }
    }

    var utilityAssetBalance: AssetBalance? {
        guard let utilityAssetId = feeChainAsset?.chain.utilityChainAssetId() else {
            return nil
        }

        return balances[utilityAssetId]
    }

    private(set) var prices: [ChainAssetId: PriceData] = [:]

    var payAssetPriceData: PriceData? {
        payChainAsset.flatMap { prices[$0.chainAssetId] }
    }

    var receiveAssetPriceData: PriceData? {
        receiveChainAsset.flatMap { prices[$0.chainAssetId] }
    }

    var feeAssetPriceData: PriceData? {
        feeChainAsset.flatMap { prices[$0.chainAssetId] }
    }

    var assetBalanceExistences: [ChainAssetId: AssetBalanceExistence] = [:]

    var payAssetBalanceExistense: AssetBalanceExistence? {
        payChainAsset.flatMap { assetBalanceExistences[$0.chainAssetId] }
    }

    var receiveAssetBalanceExistense: AssetBalanceExistence? {
        receiveChainAsset.flatMap { assetBalanceExistences[$0.chainAssetId] }
    }

    var feeAssetBalanceExistense: AssetBalanceExistence? {
        feeChainAsset.flatMap { assetBalanceExistences[$0.chainAssetId] }
    }

    var utilityAssetBalanceExistense: AssetBalanceExistence? {
        feeChainAsset?.chain.utilityChainAsset().flatMap {
            assetBalanceExistences[$0.chainAssetId]
        }
    }
    
    var fee: AssetConversion.FeeModel?
    var quote: AssetConversion.Quote?
    
    func getPayChainAsset() -> ChainAsset? {
        nil
    }
    
    func getReceiveChainAsset() -> ChainAsset? {
        nil
    }
    
    func getFeeChainAsset() -> ChainAsset? {
        nil
    }
    
    func shouldHandleQuote(for args: AssetConversion.QuoteArgs?) -> Bool {
        true
    }
    
    func shouldHandleFee(for feeIdentifier: TransactionFeeId, feeChainAssetId: ChainAssetId) -> Bool {
        true
    }
    
    func handleBaseError(
        _ error: SwapBaseError,
        view: ControllerBackedProtocol?,
        interactor: SwapBaseInteractorInputProtocol,
        wireframe: SwapBaseWireframeProtocol,
        locale: Locale
    ) {
        logger.error("Did receive base error: \(baseError)")

        switch baseError {
        case let .quote(_, args):
            guard shouldHandleQuote(for: args) else {
                return
            }
            
            wireframe.presentRequestStatus(on: view, locale: locale) { [weak self] in
                interactor.calculateQuote(for: args)
            }
        case let .fetchFeeFailed(_, id, feeChainAssetId):
            guard shouldHandleFee(for: id, feeChainAssetId: feeChainAssetId) else {
                return
            }

            wireframe.presentRequestStatus(on: view, locale: locale) { [weak self] in
                self?.estimateFee()
            }
        case let .price(_, priceId):
            wireframe.presentRequestStatus(on: view, locale: locale) { [weak self] in
                guard let self = self else {
                    return
                }
                [self.getPayChainAsset(), self.getReceiveChainAsset(), self.getFeeChainAsset()]
                    .compactMap { $0 }
                    .filter { $0.asset.priceId == priceId }
                    .forEach(interactor.remakePriceSubscription)
            }
        case let .assetBalance(_, chainAssetId, _):
            wireframe.presentRequestStatus(on: view, locale: locale) { [weak self] in
                guard let self = self else {
                    return
                }
                [self.getPayChainAsset(), self.getReceiveChainAsset(), self.getFeeChainAsset()]
                    .compactMap { $0 }
                    .filter { $0.chainAssetId == chainAssetId }
                    .forEach(interactor.retryAssetBalanceSubscription)
            }
        case let .assetBalanceExistense(_, chainAsset):
            wireframe.presentRequestStatus(on: view, locale: locale) { [weak self] in
                interactor.retryAssetBalanceExistenseFetch(for: chainAsset)
            }
        }
    }
}
