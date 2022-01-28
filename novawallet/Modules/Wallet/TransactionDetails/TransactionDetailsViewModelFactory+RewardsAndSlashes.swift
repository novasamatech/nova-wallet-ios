import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk
import IrohaCrypto

extension TransactionDetailsViewModelFactory {
    func createRewardAndSlashViewModels(
        isReward: Bool,
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> [WalletFormViewBindingProtocol]? {
        var viewModels: [WalletFormViewBindingProtocol] = []

        populateEventId(
            in: &viewModels,
            data: data,
            commandFactory: commandFactory,
            locale: locale
        )

        let context = HistoryRewardContext(context: data.context ?? [:])

        if let validator = context.validator {
            populateValidator(
                in: &viewModels,
                address: validator,
                commandFactory: commandFactory,
                locale: locale
            )
        }

        populateStatus(into: &viewModels, data: data, locale: locale)
        populateTime(into: &viewModels, data: data, locale: locale)

        if let era = context.era {
            populateEra(in: &viewModels, era: era, locale: locale)
        }

        let title = isReward ?
            R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages) :
            R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages)
        populateAmount(into: &viewModels, title: title, data: data, locale: locale)

        return viewModels
    }

    func createRewardAndSlashAccessoryViewModel(
        data _: AssetTransactionData,
        commandFactory _: WalletCommandFactoryProtocol,
        locale _: Locale
    ) -> AccessoryViewModelProtocol? {
        nil
    }

    private func populateValidator(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        address: String,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable
            .stakingCommonValidator(preferredLanguages: locale.rLanguages)
        populatePeerViewModel(
            in: &viewModelList,
            title: title,
            address: address,
            commandFactory: commandFactory,
            locale: locale
        )
    }

    private func populateEra(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        era: Int,
        locale: Locale
    ) {
        let eraString = integerFormatter.value(for: locale).string(from: NSNumber(value: era)) ??
            String(era)
        let details = R.string.localizable.commonEraFormat(eraString, preferredLanguages: locale.rLanguages)

        let title = R.string.localizable.stakingCommonEra(preferredLanguages: locale.rLanguages)
        let viewModel = WalletNewFormDetailsViewModel(
            title: title,
            titleIcon: nil,
            details: details,
            detailsIcon: nil
        )

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    func populateEventId(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title: String
        let details: String

        let command: WalletCommandProtocol

        if let rawContext = data.context {
            let context = HistoryRewardContext(context: rawContext)
            title = R.string.localizable.stakingCommonEventId(preferredLanguages: locale.rLanguages)
            details = context.eventId

            command = WalletEventOpenCommand(
                eventId: context.eventId,
                explorers: explorers,
                commandFactory: commandFactory,
                locale: locale
            )
        } else {
            title = R.string.localizable
                .transactionDetailsHashTitle(preferredLanguages: locale.rLanguages)
            details = data.peerId
            command = WalletExtrinsicOpenCommand(
                extrinsicHash: data.peerId,
                explorers: explorers,
                commandFactory: commandFactory,
                locale: locale
            )
        }

        let actionIcon = R.image.iconMore()

        let viewModel = WalletCompoundDetailsViewModel(
            title: title,
            details: details,
            mainIcon: nil,
            actionIcon: actionIcon,
            command: command,
            enabled: true
        )
        viewModelList.append(viewModel)
    }
}
