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

    func didReceiveFee(_ fee: BigUInt) {
        self.fee = fee
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

    func didReceiveSetup(error _: Error) {}
}
