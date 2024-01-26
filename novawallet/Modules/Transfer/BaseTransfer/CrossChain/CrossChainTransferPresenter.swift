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

    var senderUtilityBalanceCountingEd: BigUInt? {
        isOriginUtilityTransfer ? senderSendingAssetBalance?.balanceCountingEd :
            senderUtilityAssetBalance?.balanceCountingEd
    }

    var senderUtilityAssetTransferable: BigUInt? {
        isOriginUtilityTransfer ? senderSendingAssetBalance?.transferable : senderUtilityAssetBalance?.transferable
    }

    private(set) lazy var iconGenerator = PolkadotIconGenerator()

    private(set) var networkFee: ExtrinsicFeeProtocol?
    private(set) var crossChainFee: XcmFeeModelProtocol?

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

    var displayOriginFee: BigUInt? {
        // this is paid in the native token

        if networkFee != nil {
            return (networkFee?.amountForCurrentAccount ?? 0) + (crossChainFee?.senderPart ?? 0)
        } else {
            return nil
        }
    }

    var displayCrosschainFee: BigUInt? {
        // this is paid in the sending token

        crossChainFee.map(\.holdingPart)
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

    func updateOriginFee(_ newValue: ExtrinsicFeeProtocol?) {
        networkFee = newValue
    }

    func refreshCrossChainFee() {
        fatalError("Child classes must implement this method")
    }

    func askCrossChainFeeRetry() {
        fatalError("Child classes must implement this method")
    }

    func updateCrossChainFee(_ newValue: XcmFeeModelProtocol?) {
        crossChainFee = newValue
    }

    func resetRecepientBalance() {
        recepientSendingAssetBalance = nil
        recepientUtilityAssetBalance = nil
    }

    // swiftlint:disable:next function_body_length
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

            dataValidatingFactory.has(fee: networkFee, locale: selectedLocale) { [weak self] in
                self?.refreshOriginFee()
                return
            },

            dataValidatingFactory.has(crosschainFee: crossChainFee, locale: selectedLocale) { [weak self] in
                self?.refreshCrossChainFee()
                return
            },

            // check whether sending amount and might be origin fee might be spent
            // for cross chain there is a separate check
            dataValidatingFactory.canSpendAmountInPlank(
                balance: senderSendingAssetBalance?.transferable,
                spendingAmount: sendingAmount,
                asset: originChainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),

            dataValidatingFactory.canPayFeeSpendingAmountInPlank(
                balance: senderUtilityAssetTransferable,
                fee: networkFee,
                spendingAmount: isOriginUtilityTransfer ? sendingAmount : nil,
                asset: utilityAssetInfo,
                locale: selectedLocale
            ),

            dataValidatingFactory.notViolatingMinBalancePaying(
                fee: networkFee,
                total: senderUtilityBalanceCountingEd,
                minBalance: isOriginUtilityTransfer ? originSendingMinBalance : originUtilityMinBalance,
                locale: selectedLocale
            ),

            dataValidatingFactory.canPayOriginDeliveryFee(
                for: isOriginUtilityTransfer ? sendingAmount : 0,
                networkFee: networkFee,
                crosschainFee: crossChainFee,
                transferable: senderUtilityAssetTransferable,
                locale: selectedLocale
            ),

            // check whether cross chain fee can be paid after sending amount and paying origin fee
            dataValidatingFactory.canPayCrossChainFee(
                for: sendingAmount,
                fee: (
                    origin: isOriginUtilityTransfer ? displayOriginFee : nil,
                    crossChain: displayCrosschainFee
                ),
                transferable: senderSendingAssetBalance?.transferable,
                destinationAsset: destinationChainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),

            dataValidatingFactory.receiverWillHaveAssetAccount(
                sendingAmount: sendingAmount,
                totalAmount: recepientSendingAssetBalance?.balanceCountingEd,
                minBalance: destSendingExistence?.minBalance,
                locale: selectedLocale
            ),

            dataValidatingFactory.receiverNotBlocked(
                recepientSendingAssetBalance?.blocked,
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

    func didReceiveOriginFee(result: Result<ExtrinsicFeeProtocol, Error>) {
        switch result {
        case let .success(fee):
            networkFee = fee
        case let .failure(error):
            logger?.error("Origin fee error: \(error)")

            askOriginFeeRetry()
        }
    }

    func didReceiveCrossChainFee(result: Result<XcmFeeModelProtocol, Error>) {
        switch result {
        case let .success(fee):
            crossChainFee = fee
        case let .failure(error):
            logger?.error("Crosschain fee error: \(error)")

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
