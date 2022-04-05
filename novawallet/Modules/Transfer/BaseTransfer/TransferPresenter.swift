import Foundation
import BigInt
import SubstrateSdk

class TransferPresenter {
    let chainAsset: ChainAsset

    let senderAccountAddress: AccountAddress

    private(set) var senderSendingAssetBalance: AssetBalance?
    private(set) var senderUtilityAssetBalance: AssetBalance?

    private(set) var recepientSendingAssetBalance: AssetBalance?
    private(set) var recepientUtilityAssetBalance: AssetBalance?

    private(set) var sendingAssetPrice: PriceData?
    private(set) var utilityAssetPrice: PriceData?

    private(set) var sendingAssetMinBalance: BigUInt?
    private(set) var utilityAssetMinBalance: BigUInt?

    var senderUtilityAssetTotal: BigUInt? {
        isUtilityTransfer ? senderSendingAssetBalance?.totalInPlank :
            senderUtilityAssetBalance?.totalInPlank
    }

    private(set) lazy var iconGenerator = PolkadotIconGenerator()

    private(set) var fee: BigUInt?

    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol
    let utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?

    let dataValidatingFactory: TransferDataValidatorFactoryProtocol

    let logger: LoggerProtocol?

    var isUtilityTransfer: Bool {
        chainAsset.chain.utilityAssets().first?.assetId == chainAsset.asset.assetId
    }

    init(
        chainAsset: ChainAsset,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        sendingBalanceViewModelFactory: BalanceViewModelFactoryProtocol,
        utilityBalanceViewModelFactory: BalanceViewModelFactoryProtocol?,
        senderAccountAddress: AccountAddress,
        dataValidatingFactory: TransferDataValidatorFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.chainAsset = chainAsset
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

    func updateFee(_ newValue: BigUInt?) {
        fee = newValue
    }

    func baseValidators(
        for sendingAmount: Decimal?,
        recepientAddress: AccountAddress?,
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

            dataValidatingFactory.has(fee: fee, locale: selectedLocale) { [weak self] in
                self?.refreshFee()
                return
            },

            dataValidatingFactory.canSend(
                amount: sendingAmount,
                fee: isUtilityTransfer ? fee : 0,
                transferable: senderSendingAssetBalance?.transferable,
                locale: selectedLocale
            ),

            dataValidatingFactory.canPay(
                fee: fee,
                total: senderUtilityAssetTotal,
                minBalance: isUtilityTransfer ? sendingAssetMinBalance : utilityAssetMinBalance,
                locale: selectedLocale
            ),

            dataValidatingFactory.receiverWillHaveAssetAccount(
                sendingAmount: sendingAmount,
                totalAmount: recepientSendingAssetBalance?.totalInPlank,
                minBalance: sendingAssetMinBalance,
                locale: selectedLocale
            )
        ]

        if !isUtilityTransfer {
            validators.append(
                dataValidatingFactory.receiverHasUtilityAccount(
                    totalAmount: recepientUtilityAssetBalance?.totalInPlank,
                    minBalance: utilityAssetMinBalance,
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

    func didReceiveFee(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(fee):
            self.fee = fee
        case .failure:
            askFeeRetry()
        }
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

    func didReceiveSendingAssetMinBalance(_ value: BigUInt) {
        sendingAssetMinBalance = value
    }

    func didCompleteSetup() {}

    func didReceiveError(_: Error) {}
}
