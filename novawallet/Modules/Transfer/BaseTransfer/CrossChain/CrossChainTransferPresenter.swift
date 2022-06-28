import Foundation
import BigInt
import SubstrateSdk

class CrossChainTransferPresenter {
    let originChainAsset: ChainAsset
    let destinationChainAsset: ChainAsset

    private(set) var senderSendingAssetBalance: AssetBalance?
    private(set) var senderUtilityAssetBalance: AssetBalance?

    private(set) var recepientSendingAssetBalance: AssetBalance?
    private(set) var recepientUtilityAssetBalance: AssetBalance?

    private(set) var sendingAssetPrice: PriceData?
    private(set) var utilityAssetPrice: PriceData?

    private(set) var originSendingMinBalance: BigUInt?
    private(set) var originUtilityMinBalance: BigUInt?
    private(set) var destSendingExistence: AssetBalanceExistence?
    private(set) var destUtilityMinBalance: BigUInt?

    var senderUtilityAssetTotal: BigUInt? {
        isOriginUtilityTransfer ? senderSendingAssetBalance?.totalInPlank :
            senderUtilityAssetBalance?.totalInPlank
    }

    var senderUtilityAssetTransferable: BigUInt? {
        isOriginUtilityTransfer ? senderSendingAssetBalance?.transferable : senderUtilityAssetBalance?.transferable
    }

    private(set) lazy var iconGenerator = PolkadotIconGenerator()

    private(set) var originFee: BigUInt?
    private(set) var crossChainFee: FeeWithWeight?

    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol
    let utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?

    let dataValidatingFactory: TransferDataValidatorFactoryProtocol

    let logger: LoggerProtocol?

    var isOriginUtilityTransfer: Bool {
        originChainAsset.chain.utilityAssets().first?.assetId == originChainAsset.asset.assetId
    }

    var isDestUtilityTransfer: Bool {
        destinationChainAsset.chain.utilityAssets().first?.assetId == destinationChainAsset.asset.assetId
    }

    init(
        originChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
        dataValidatingFactory: TransferDataValidatorFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.originChainAsset = originChainAsset
        self.destinationChainAsset = destinationChainAsset
        self.networkViewModelFactory = networkViewModelFactory
        self.sendingBalanceViewModelFactory = sendingBalanceViewModelFactory
        self.utilityBalanceViewModelFactory = utilityBalanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
    }

    func refreshOriginFee() {
        fatalError("Child classes must implement this method")
    }

    func askOriginFeeRetry() {
        fatalError("Child classes must implement this method")
    }

    func updateOriginFee(_ newValue: BigUInt?) {
        originFee = newValue
    }

    func refreshCrossChainFee() {
        fatalError("Child classes must implement this method")
    }

    func askCrossChainFeeRetry() {
        fatalError("Child classes must implement this method")
    }

    func updateCrossChainFee(_ newValue: BigUInt?) {
        originFee = newValue
    }

    func resetRecepientBalance() {
        recepientSendingAssetBalance = nil
        recepientUtilityAssetBalance = nil
    }

    private func totalFee() -> BigUInt? {
        let optDestSendingFee = crossChainFee?.fee
        let optOriginSendingFee: BigUInt? = (isOriginUtilityTransfer ? originFee : 0)

        if let originSendingFee = optOriginSendingFee, let destSendingFee = optDestSendingFee {
            return originSendingFee + destSendingFee
        } else {
            return nil
        }
    }

    func baseValidators(
        for sendingAmount: Decimal?,
        recepientAddress: AccountAddress?,
        utilityAssetInfo: AssetBalanceDisplayInfo,
        selectedLocale: Locale
    ) -> [DataValidating] {
        var validators: [DataValidating] = [
            dataValidatingFactory.receiverMatchesChain(
                recepient: recepientAddress,
                chainFormat: destinationChainAsset.chain.chainFormat,
                chainName: destinationChainAsset.chain.name,
                locale: selectedLocale
            ),

            dataValidatingFactory.has(fee: originFee, locale: selectedLocale) { [weak self] in
                self?.refreshOriginFee()
                return
            },

            dataValidatingFactory.has(fee: crossChainFee?.fee, locale: selectedLocale) { [weak self] in
                self?.refreshCrossChainFee()
                return
            },

            dataValidatingFactory.canSend(
                amount: sendingAmount,
                fee: totalFee(),
                transferable: senderSendingAssetBalance?.transferable,
                locale: selectedLocale
            ),

            dataValidatingFactory.canPayFeeInPlank(
                balance: senderUtilityAssetTransferable,
                fee: originFee,
                asset: utilityAssetInfo,
                locale: selectedLocale
            ),

            dataValidatingFactory.notViolatingMinBalancePaying(
                fee: originFee,
                total: senderUtilityAssetTotal,
                minBalance: isOriginUtilityTransfer ? originSendingMinBalance : originUtilityMinBalance,
                locale: selectedLocale
            ),

            dataValidatingFactory.receiverWillHaveAssetAccount(
                sendingAmount: sendingAmount,
                totalAmount: recepientSendingAssetBalance?.totalInPlank,
                minBalance: destSendingExistence?.minBalance,
                locale: selectedLocale
            )
        ]

        if !isDestUtilityTransfer {
            validators.append(
                dataValidatingFactory.receiverHasAccountProvider(
                    utilityTotalAmount: recepientUtilityAssetBalance?.totalInPlank,
                    utilityMinBalance: destUtilityMinBalance,
                    assetExistence: destSendingExistence,
                    locale: selectedLocale
                )
            )
        }

        return validators
    }

    func didReceiveSendingAssetSenderBalance(_ balance: AssetBalance) {
        senderSendingAssetBalance = balance
    }

    func didReceiveUtilityAssetSenderBalance(_ balance: AssetBalance) {
        senderUtilityAssetBalance = balance
    }

    func didReceiveSendingAssetRecepientBalance(_ balance: AssetBalance) {
        recepientSendingAssetBalance = balance
    }

    func didReceiveUtilityAssetRecepientBalance(_ balance: AssetBalance) {
        recepientUtilityAssetBalance = balance
    }

    func didReceiveOriginFee(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(fee):
            originFee = fee
        case .failure:
            askOriginFeeRetry()
        }
    }

    func didReceiveCrossChainFee(result: Result<FeeWithWeight, Error>) {
        switch result {
        case let .success(fee):
            crossChainFee = fee
        case .failure:
            askCrossChainFeeRetry()
        }
    }

    func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        sendingAssetPrice = priceData
    }

    func didReceiveUtilityAssetPrice(_ priceData: PriceData?) {
        utilityAssetPrice = priceData
    }

    func didReceiveOriginSendingMinBalance(_ value: BigUInt) {
        originSendingMinBalance = value
    }

    func didReceiveOriginUtilityMinBalance(_ value: BigUInt) {
        originUtilityMinBalance = value
    }

    func didReceiveDestSendingExistence(_ value: AssetBalanceExistence) {
        destSendingExistence = value
    }

    func didReceiveDestUtilityMinBalance(_ value: BigUInt) {
        destUtilityMinBalance = value
    }

    func didCompleteSetup(result _: Result<Void, Error>) {}

    func didReceiveError(_: Error) {}
}
