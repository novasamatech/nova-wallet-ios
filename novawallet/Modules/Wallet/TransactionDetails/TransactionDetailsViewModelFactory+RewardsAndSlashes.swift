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

        populateStatus(into: &viewModels, data: data, locale: locale)
        populateTime(into: &viewModels, data: data, locale: locale)

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

    func populateEventId(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable
            .transactionDetailsHashTitle(preferredLanguages: locale.rLanguages)

        let actionIcon = R.image.iconMore()

        let command = WalletExtrinsicOpenCommand(
            extrinsicHash: data.peerId,
            explorers: explorers,
            commandFactory: commandFactory,
            locale: locale
        )

        let viewModel = WalletCompoundDetailsViewModel(
            title: title,
            details: data.peerId,
            mainIcon: nil,
            actionIcon: actionIcon,
            command: command,
            enabled: true
        )
        viewModelList.append(viewModel)
    }
}
