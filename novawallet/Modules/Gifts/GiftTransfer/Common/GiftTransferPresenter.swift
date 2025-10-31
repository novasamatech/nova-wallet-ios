import Foundation
import BigInt
import SubstrateSdk

class GiftTransferPresenter {
    let chainAsset: ChainAsset

    let senderAccountAddress: AccountAddress

    private(set) var assetBalance: AssetBalance?
    private(set) var assetPrice: PriceData?

    private(set) var assetExistence: AssetBalanceExistence?

    var senderFeeBalanceCountingEd: BigUInt? {
        assetBalance?.balanceCountingEd
    }

    var senderFeeAssetTransferable: BigUInt? {
        assetBalance?.transferable
    }

    private(set) lazy var iconGenerator = PolkadotIconGenerator()

    private(set) var fee: FeeOutputModel?
    private(set) var feeDescription: GiftFeeDescription?
    var feeAsset: ChainAsset

    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    let dataValidatingFactory: TransferDataValidatorFactoryProtocol

    let logger: LoggerProtocol?

    var isUtilityTransfer: Bool {
        chainAsset.chain.utilityAssets().first?.assetId == chainAsset.asset.assetId
    }

    init(
        chainAsset: ChainAsset,
        feeAsset: ChainAsset,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        senderAccountAddress: AccountAddress,
        dataValidatingFactory: TransferDataValidatorFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.chainAsset = chainAsset
        self.feeAsset = feeAsset
        self.networkViewModelFactory = networkViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
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

    func baseValidators(
        for sendingAmount: Decimal?,
        feeAssetInfo: AssetBalanceDisplayInfo,
        view: ControllerBackedProtocol?,
        selectedLocale: Locale
    ) -> [DataValidating] {
        var validators: [DataValidating] = [
            dataValidatingFactory.has(
                fee: fee?.value,
                locale: selectedLocale
            ) { [weak self] in
                self?.refreshFee()
                return
            },
            dataValidatingFactory.canSpendAmountInPlank(
                balance: assetBalance?.transferable,
                spendingAmount: sendingAmount,
                asset: chainAsset.assetDisplayInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.canPayFeeSpendingAmountInPlank(
                balance: senderFeeAssetTransferable,
                fee: fee?.value,
                spendingAmount: sendingAmount,
                asset: feeAssetInfo,
                locale: selectedLocale
            ),
            dataValidatingFactory.notViolatingMinBalancePaying(
                fee: fee?.value,
                total: senderFeeBalanceCountingEd,
                minBalance: assetExistence?.minBalance,
                asset: feeAssetInfo,
                locale: selectedLocale
            )
        ]

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
        assetBalance = balance
    }

    func didReceiveFee(result: Result<FeeOutputModel, Error>) {
        switch result {
        case let .success(fee):
            self.fee = fee
        case .failure:
            askFeeRetry()
        }
    }
    
    func didReceiveFee(description: GiftFeeDescription) {
        feeDescription = description
    }

    func didReceiveSendingAssetPrice(_ priceData: PriceData?) {
        assetPrice = priceData
    }

    func didReceiveSendingAssetExistence(_ value: AssetBalanceExistence) {
        assetExistence = value
    }

    func didReceiveUtilityAssetSenderBalance(_: AssetBalance) {}

    func didReceiveSendingAssetRecepientBalance(_: AssetBalance) {}

    func didReceiveUtilityAssetRecepientBalance(_: AssetBalance) {}

    func didReceiveCustomAssetFeeAvailable(_: Bool) {}

    func didReceiveUtilityAssetPrice(_: PriceData?) {}

    func didReceiveUtilityAssetMinBalance(_: BigUInt) {}

    func didCompleteSetup() {}

    func didReceiveError(_: Error) {}
}
