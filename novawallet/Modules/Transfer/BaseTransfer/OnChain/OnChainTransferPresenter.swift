import Foundation
import BigInt
import SubstrateSdk

class OnChainTransferPresenter {
    let chainAsset: ChainAsset

    let senderAccountAddress: AccountAddress

    private(set) var senderSendingAssetBalance: AssetBalance?
    private(set) var senderUtilityAssetBalance: AssetBalance?

    private(set) var recepientSendingAssetBalance: AssetBalance?
    private(set) var recepientUtilityAssetBalance: AssetBalance?

    private(set) var sendingAssetPrice: PriceData?
    private(set) var utilityAssetPrice: PriceData?

    private(set) var sendingAssetExistence: AssetBalanceExistence?
    private(set) var utilityAssetMinBalance: BigUInt?

    var senderFeeBalanceCountingEd: BigUInt? {
        sendingAssetFeeSelected
            ? senderSendingAssetBalance?.balanceCountingEd
            : senderUtilityAssetBalance?.balanceCountingEd
    }

    var senderFeeAssetTransferable: BigUInt? {
        sendingAssetFeeSelected
            ? senderSendingAssetBalance?.transferable
            : senderUtilityAssetBalance?.transferable
    }

    private(set) lazy var iconGenerator = PolkadotIconGenerator()

    private(set) var fee: FeeOutputModel?
    var feeAsset: ChainAsset

    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol
    let utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?

    let dataValidatingFactory: TransferDataValidatorFactoryProtocol

    let logger: LoggerProtocol?

    var sendingAssetFeeAvailable: Bool?

    var isUtilityTransfer: Bool {
        chainAsset.chain.utilityAssets().first?.assetId == chainAsset.asset.assetId
    }

    var sendingAssetFeeSelected: Bool {
        feeAsset.chainAssetId == chainAsset.chainAssetId
    }

    var feeAssetChangeAvailable: Bool {
        chainAsset.chain.hasCustomFees
            && sendingAssetFeeAvailable ?? false
            && !isUtilityTransfer
    }

    init(
        chainAsset: ChainAsset,
        feeAsset: ChainAsset,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
        senderAccountAddress: AccountAddress,
        dataValidatingFactory: TransferDataValidatorFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.chainAsset = chainAsset
        self.feeAsset = feeAsset
        self.networkViewModelFactory = networkViewModelFactory
        self.sendingBalanceViewModelFactory = sendingBalanceViewModelFactory
        self.utilityBalanceViewModelFactory = utilityBalanceViewModelFactory
        self.senderAccountAddress = senderAccountAddress
        self.dataValidatingFactory = dataValidatingFactory
        self.logger = logger
    }

    func refreshFee() {
        fatalError("Child classes must implement this method")
    }

    func askFeeRetry() {
        fatalError("Child classes must implement this method")
    }

    func updateFee(_ newValue: FeeOutputModel?) {
        fee = newValue
    }

    func resetRecepientBalance() {
        recepientSendingAssetBalance = nil
        recepientUtilityAssetBalance = nil
    }

    func baseValidators(
        for sendingAmount: Decimal?,
        recepientAddress: AccountAddress?,
        feeAssetInfo: AssetBalanceDisplayInfo,
        view: ControllerBackedProtocol?,
        selectedLocale: Locale
    ) -> [DataValidating] {
        var validators: [DataValidating] = [
            dataValidatingFactory.receiverMatchesChain(
                recepient: recepientAddress,
                chainFormat: chainAsset.chain.chainFormat,
                chainName: chainAsset.chain.name,
                locale: selectedLocale
            ),

            dataValidatingFactory.receiverDiffers(
                recepient: recepientAddress,
                sender: senderAccountAddress,
                locale: selectedLocale
            ),

            dataValidatingFactory.has(
                fee: fee?.value,
                locale: selectedLocale
            ) { [weak self] in
                self?.refreshFee()
                return
            },

            dataValidatingFactory.canSpendAmountInPlank(
                balance: senderSendingAssetBalance?.transferable,
                spendingAmount: sendingAmount,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),

            dataValidatingFactory.canPayFeeSpendingAmountInPlank(
                balance: senderFeeAssetTransferable,
                fee: fee?.value,
                spendingAmount: sendingAssetFeeSelected ? sendingAmount : nil,
                asset: feeAssetInfo,
                locale: selectedLocale
            ),

            dataValidatingFactory.notViolatingMinBalancePaying(
                fee: fee?.value,
                total: senderFeeBalanceCountingEd,
                minBalance: sendingAssetFeeSelected ? sendingAssetExistence?.minBalance : utilityAssetMinBalance,
                asset: feeAssetInfo,
                locale: selectedLocale
            ),

            dataValidatingFactory.receiverWillHaveAssetAccount(
                sendingAmount: sendingAmount,
                totalAmount: recepientSendingAssetBalance?.balanceCountingEd,
                minBalance: sendingAssetExistence?.minBalance,
                locale: selectedLocale
            ),

            dataValidatingFactory.receiverNotBlocked(
                recepientSendingAssetBalance?.blocked,
                locale: selectedLocale
            )
        ]

        if !isUtilityTransfer {
            let accountProviderValidation = dataValidatingFactory.receiverHasAccountProvider(
                utilityTotalAmount: recepientUtilityAssetBalance?.totalInPlank,
                utilityMinBalance: utilityAssetMinBalance,
                assetExistence: sendingAssetExistence,
                locale: selectedLocale
            )

            validators.append(accountProviderValidation)
        }

        let optFeeValidation = fee?.validationProvider?.getValidations(
            for: view,
            onRefresh: { [weak self] in
                self?.refreshFee()
            },
            locale: selectedLocale
        )

        if let feeValidation = optFeeValidation {
            validators.append(feeValidation)
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

    func didReceiveFee(result: Result<FeeOutputModel, Error>) {
        switch result {
        case let .success(fee):
            self.fee = fee
        case .failure:
            askFeeRetry()
        }
    }

    func didReceiveCustomAssetFeeAvailable(_ available: Bool) {
        sendingAssetFeeAvailable = available
    }

    func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        sendingAssetPrice = priceData
    }

    func didReceiveUtilityAssetPrice(_ priceData: PriceData?) {
        utilityAssetPrice = priceData
    }

    func didReceiveUtilityAssetMinBalance(_ value: BigUInt) {
        utilityAssetMinBalance = value
    }

    func didReceiveSendingAssetExistence(_ value: AssetBalanceExistence) {
        sendingAssetExistence = value
    }

    func didCompleteSetup() {}

    func didReceiveError(_: Error) {}
}
