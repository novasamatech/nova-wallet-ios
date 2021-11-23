import Foundation
import CommonWallet
import SubstrateSdk

final class TransferConfirmViewModelFactory {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let chainAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        chainAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chainAccount = chainAccount
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    private func getPriceDataFrom(_ transferInfo: TransferInfo) -> PriceData? {
        let priceContext = BalanceContext(context: transferInfo.context ?? [:])
        let price = priceContext.price

        guard price > 0.0 else { return nil }

        return PriceData(price: price.stringWithPointSeparator, usdDayChange: nil)
    }

    private func populateSender(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload _: ConfirmationPayload,
        locale: Locale
    ) {
        guard let commandFactory = commandFactory,
              let senderAddress = chainAccount.toAddress(),
              let senderDisplayAddress = try? chainAccount.toDisplayAddress().address,
              let senderDisplayName = try? chainAccount.toDisplayAddress().username
        else { return }

        let headerTitle = R.string.localizable
            .transactionDetailsFrom(preferredLanguages: locale.rLanguages)

        let iconGenerator = PolkadotIconGenerator()
        let icon = try? iconGenerator.generateFromAddress(senderAddress)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        let command = WalletAccountOpenCommand(
            address: senderDisplayAddress,
            explorers: chainAsset.chain.explorers,
            commandFactory: commandFactory,
            locale: locale
        )

        let viewModel = WalletCompoundDetailsViewModel(
            title: headerTitle,
            details: senderDisplayName,
            mainIcon: icon,
            actionIcon: R.image.iconMore(),
            command: command,
            enabled: true
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.none]))
    }

    private func populateReceiver(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        locale: Locale
    ) {
        guard let commandFactory = commandFactory else {
            return
        }

        let headerTitle = R.string.localizable
            .walletSendReceiverTitle(preferredLanguages: locale.rLanguages)

        let icon: UIImage?

        if let accountId = try? payload.receiverName.toAccountId() {
            let iconGenerator = PolkadotIconGenerator()
            icon = try? iconGenerator.generateFromAccountId(accountId)
                .imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
        } else {
            icon = nil
        }

        let command = WalletAccountOpenCommand(
            address: payload.receiverName,
            explorers: chainAsset.chain.explorers,
            commandFactory: commandFactory,
            locale: locale
        )

        let viewModel = WalletCompoundDetailsViewModel(
            title: headerTitle,
            details: payload.receiverName,
            mainIcon: icon,
            actionIcon: R.image.iconMore(),
            command: command,
            enabled: true
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.none]))
    }

    private func populateSendingAmount(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        chainAsset: ChainAsset,
        locale: Locale
    ) {
        let assetInfo = chainAsset.assetDisplayInfo

        let decimalAmount = payload.transferInfo.amount.decimalValue
        let priceData = getPriceDataFrom(payload.transferInfo)

        let inputBalance = balanceViewModelFactory
            .balanceFromPrice(decimalAmount, priceData: priceData).value(for: locale)

        let balanceContext = BalanceContext(context: payload.transferInfo.context ?? [:])
        let availableBalance = balanceViewModelFactory.amountFromValue(balanceContext.available).value(for: locale)

        let displayBalance = R.string.localizable.commonAvailableFormat(
            availableBalance,
            preferredLanguages: locale.rLanguages
        )

        let title = R.string.localizable.walletSendAmountTitle(
            preferredLanguages: locale.rLanguages
        )

        let iconViewModel = assetInfo.icon.map { RemoteImageViewModel(url: $0) }

        let viewModel = RichAmountDisplayViewModel(
            title: title,
            amount: inputBalance.amount,
            symbol: assetInfo.symbol,
            balance: displayBalance,
            price: inputBalance.price,
            iconViewModel: iconViewModel
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: .none))
    }
}

extension TransferConfirmViewModelFactory: TransferConfirmationViewModelFactoryOverriding {
    func createViewModelsFromPayload(
        _ payload: ConfirmationPayload,
        locale: Locale
    ) -> [WalletFormViewBindingProtocol]? {
        var viewModelList: [WalletFormViewBindingProtocol] = []

        populateSender(in: &viewModelList, payload: payload, locale: locale)
        populateReceiver(in: &viewModelList, payload: payload, locale: locale)
        populateSendingAmount(in: &viewModelList, payload: payload, chainAsset: chainAsset, locale: locale)

        return viewModelList
    }

    func createAccessoryViewModelFromPayload(
        _ payload: ConfirmationPayload,
        locale: Locale
    ) -> AccessoryViewModelProtocol? {
        let fee = payload.transferInfo.fees
            .map(\.value.decimalValue)
            .reduce(0.0, +)

        let amount = balanceViewModelFactory.amountFromValue(fee).value(for: locale)

        let actionTitle = R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages)
        let title = R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)

        let priceData = getPriceDataFrom(payload.transferInfo)

        let price: String? = {
            guard let amount = Decimal(string: amount),
                  let priceData = priceData
            else { return nil }

            return balanceViewModelFactory.balanceFromPrice(
                amount,
                priceData: priceData
            ).value(for: locale).price ?? nil
        }()

        return ExtrinisicConfirmViewModel(
            title: title,
            amount: amount,
            price: price,
            icon: nil,
            action: actionTitle,
            numberOfLines: 1,
            shouldAllowAction: true
        )
    }
}
