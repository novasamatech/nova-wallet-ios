import Foundation
import CommonWallet
import IrohaCrypto
import SubstrateSdk

final class TransferViewModelFactory: TransferViewModelFactoryOverriding {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let chainAsset: ChainAsset
    let explorers: [ChainModel.Explorer]?
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let feeViewModelFactory: BalanceViewModelFactoryProtocol?

    init(
        chainAsset: ChainAsset,
        explorers: [ChainModel.Explorer]?,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        feeViewModelFactory: BalanceViewModelFactoryProtocol?
    ) {
        self.chainAsset = chainAsset
        self.explorers = explorers
        self.balanceViewModelFactory = balanceViewModelFactory
        self.feeViewModelFactory = feeViewModelFactory
    }

    private func getTransferPriceDataFrom(_ inputState: TransferInputState) -> PriceData? {
        let priceContext = TransferMetadataContext(context: inputState.metadata?.context ?? [:])
        let price = priceContext.transferAssetPrice

        guard price > 0.0 else { return nil }

        return PriceData(price: price.stringWithPointSeparator, usdDayChange: nil)
    }

    private func getFeePriceDataFrom(_ inputState: TransferInputState) -> PriceData? {
        let priceContext = FeeMetadataContext(
            context: inputState.metadata?.feeDescriptions.first?.context ?? [:]
        )

        let price = priceContext.feeAssetPrice

        guard price > 0.0 else { return nil }

        return PriceData(price: price.stringWithPointSeparator, usdDayChange: nil)
    }

    func createFeeViewModel(
        _ inputState: TransferInputState,
        fee: Fee,
        payload _: TransferPayload,
        locale: Locale
    ) throws -> FeeViewModelProtocol? {
        let title = R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)

        let feeAmount = fee.feeDescription.parameters.first?.decimalValue ?? 0

        let priceData = getFeePriceDataFrom(inputState)

        let feeFactory = feeViewModelFactory ?? balanceViewModelFactory
        let balance = feeFactory.balanceFromPrice(
            feeAmount,
            priceData: priceData
        ).value(for: locale)

        return FeePriceViewModel(
            amount: balance.amount,
            price: balance.price,
            title: title,
            details: balance.amount,
            isLoading: false,
            allowsEditing: false
        )
    }

    func createDescriptionViewModel(
        _: TransferInputState,
        details _: String?,
        payload _: TransferPayload,
        locale _: Locale
    ) throws
        -> WalletOverridingResult<DescriptionInputViewModelProtocol?>? {
        WalletOverridingResult(item: nil)
    }

    func createAssetSelectionTitle(
        _: TransferInputState,
        payload _: TransferPayload,
        locale _: Locale
    ) throws -> String? {
        nil
    }

    func createReceiverViewModel(
        _: TransferInputState,
        payload: TransferPayload,
        locale: Locale
    ) throws -> MultilineTitleIconViewModelProtocol? {
        guard let commandFactory = commandFactory else { return nil }

        let header = R.string.localizable
            .walletSendReceiverTitle(preferredLanguages: locale.rLanguages)

        let icon: UIImage?

        let accountId = try Data(hexString: payload.receiveInfo.accountId)

        let iconGenerator = PolkadotIconGenerator()
        icon = try? iconGenerator.generateFromAccountId(accountId).imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.smallAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        let address = try accountId.toAddress(using: chainAsset.chain.chainFormat)

        let command = WalletAccountOpenCommand(
            address: address,
            explorers: explorers,
            commandFactory: commandFactory,
            locale: locale
        )

        let viewModel = WalletCompoundDetailsViewModel(
            title: header,
            details: address,
            mainIcon: icon,
            actionIcon: R.image.iconMore(),
            command: command,
            enabled: true
        )

        return viewModel
    }

    func createAccessoryViewModel(
        _: TransferInputState,
        payload _: TransferPayload?,
        locale: Locale
    ) throws -> AccessoryViewModelProtocol? {
        let action = R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
        return AccessoryViewModel(title: "", action: action)
    }

    func createAmountViewModel(
        _ inputState: TransferInputState,
        payload _: TransferPayload,
        locale: Locale
    ) throws -> AmountInputViewModelProtocol? {
        let assetInfo = chainAsset.assetDisplayInfo

        let balanceContext = BalanceContext(context: inputState.balance?.context ?? [:])
        let balance = balanceViewModelFactory.amountFromValue(balanceContext.available).value(for: locale)

        let amountInputViewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputState.amount
        ).value(for: locale)

        let fee = inputState.metadata?.feeDescriptions.first?.parameters.first?.decimalValue ?? .zero

        let priceData = getTransferPriceDataFrom(inputState)

        let iconViewModel = assetInfo.icon.map { RemoteImageViewModel(url: $0) }

        let viewModel: RichAmountInputViewModelProtocol = RichAmountInputViewModel(
            amountInputViewModel: amountInputViewModel,
            balanceViewModelFactory: balanceViewModelFactory,
            symbol: assetInfo.symbol,
            iconViewModel: iconViewModel,
            balance: balance,
            priceData: priceData,
            decimalBalance: balanceContext.available,
            fee: fee,
            limit: TransferConstants.maxAmount
        )

        return viewModel
    }
}
