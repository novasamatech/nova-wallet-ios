import Foundation
import CommonWallet
import SubstrateSdk

final class TransferConfirmViewModelFactory {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let chainAsset: ChainAsset
    let amountFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(chainAsset: ChainAsset, amountFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.chainAsset = chainAsset
        self.amountFormatterFactory = amountFormatterFactory
    }

    func populateAsset(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        chainAsset: ChainAsset,
        locale: Locale
    ) {
        let assetInfo = chainAsset.assetDisplayInfo

        let headerTitle = R.string.localizable.walletSendAssetTitle(preferredLanguages: locale.rLanguages)

        let subtitle: String = R.string.localizable
            .walletSendAvailableBalance(preferredLanguages: locale.rLanguages)

        let context = BalanceContext(context: payload.transferInfo.context ?? [:])

        let amountFormatter = amountFormatterFactory.createTokenFormatter(for: assetInfo)
        let details = amountFormatter.value(for: locale).stringFromDecimal(context.available) ?? ""

        let detailsCommand: WalletCommandProtocol?

        if let commandFactory = commandFactory {
            let transferring = payload.transferInfo.amount.decimalValue
            let fee = payload.transferInfo.fees.reduce(Decimal(0.0)) { $0 + $1.value.decimalValue }
            let remaining = context.total - (transferring + fee)
            let transferState = TransferExistentialState(
                totalAmount: context.total,
                availableAmount: context.available,
                totalAfterTransfer: remaining,
                existentialDeposit: context.minimalBalance
            )

            let amountFormatter = amountFormatterFactory.createDisplayFormatter(for: assetInfo)

            detailsCommand = ExistentialDepositInfoCommand(
                transferState: transferState,
                amountFormatter: amountFormatter,
                commandFactory: commandFactory
            )
        } else {
            detailsCommand = nil
        }

        let selectedState = SelectedAssetState(isSelecting: false, canSelect: false)
        let tokenViewModel = WalletTokenViewModel(
            header: headerTitle,
            title: chainAsset.asset.name ?? chainAsset.chain.name,
            subtitle: subtitle,
            details: details,
            icon: nil, // fix icon
            state: selectedState,
            detailsCommand: detailsCommand
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: tokenViewModel, borderType: [.bottom]))
    }

    func populateFee(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        chainAsset: ChainAsset,
        locale: Locale
    ) {
        let assetInfo = chainAsset.assetDisplayInfo

        let formatter = amountFormatterFactory.createFeeTokenFormatter(for: assetInfo)

        for fee in payload.transferInfo.fees {
            let decimalAmount = fee.value.decimalValue

            guard let amount = formatter.value(for: locale).stringFromDecimal(decimalAmount) else {
                return
            }

            let title = R.string.localizable.walletSendFeeTitle(preferredLanguages: locale.rLanguages)
            let viewModel = WalletNewFormDetailsViewModel(
                title: title,
                titleIcon: nil,
                details: amount,
                detailsIcon: nil
            )
            viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
        }
    }

    func populateSendingAmount(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        chainAsset: ChainAsset,
        locale: Locale
    ) {
        let assetInfo = chainAsset.assetDisplayInfo

        let formatter = amountFormatterFactory.createInputFormatter(for: assetInfo)

        let decimalAmount = payload.transferInfo.amount.decimalValue

        guard let amount = formatter.value(for: locale).string(from: decimalAmount as NSNumber) else {
            return
        }

        let title = R.string.localizable.walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        let viewModel = WalletFormSpentAmountModel(title: title, amount: amount)
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: .none))
    }

    func populateReceiver(
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

        // TODO: Fix when subscan integrated
        let command = WalletAccountOpenCommand(
            address: payload.receiverName,
            chain: .westend,
            commandFactory: commandFactory,
            locale: locale
        )

        let viewModel = WalletCompoundDetailsViewModel(
            title: headerTitle,
            details: payload.receiverName,
            mainIcon: icon,
            actionIcon: R.image.iconMore(),
            command: command,
            enabled: false
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
    }
}

extension TransferConfirmViewModelFactory: TransferConfirmationViewModelFactoryOverriding {
    func createViewModelsFromPayload(
        _ payload: ConfirmationPayload,
        locale: Locale
    ) -> [WalletFormViewBindingProtocol]? {
        var viewModelList: [WalletFormViewBindingProtocol] = []

        populateAsset(in: &viewModelList, payload: payload, chainAsset: chainAsset, locale: locale)
        populateReceiver(in: &viewModelList, payload: payload, locale: locale)
        populateSendingAmount(in: &viewModelList, payload: payload, chainAsset: chainAsset, locale: locale)
        populateFee(in: &viewModelList, payload: payload, chainAsset: chainAsset, locale: locale)

        return viewModelList
    }

    func createAccessoryViewModelFromPayload(
        _ payload: ConfirmationPayload,
        locale: Locale
    ) -> AccessoryViewModelProtocol? {
        var decimalAmount = payload.transferInfo.amount.decimalValue

        for fee in payload.transferInfo.fees {
            decimalAmount += fee.value.decimalValue
        }

        let formatter = amountFormatterFactory.createTokenFormatter(for: chainAsset.asset.displayInfo)

        guard let amount = formatter.value(for: locale).stringFromDecimal(decimalAmount) else {
            return nil
        }

        let actionTitle = R.string.localizable.walletSendConfirmTitle(preferredLanguages: locale.rLanguages)
        let title = R.string.localizable.walletTransferTotalTitle(preferredLanguages: locale.rLanguages)

        return TransferConfirmAccessoryViewModel(
            title: title,
            icon: nil,
            action: actionTitle,
            numberOfLines: 1,
            amount: amount,
            shouldAllowAction: true
        )
    }
}
