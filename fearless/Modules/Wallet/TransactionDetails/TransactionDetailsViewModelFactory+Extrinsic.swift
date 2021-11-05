import Foundation
import CommonWallet
import SoraFoundation
import SubstrateSdk

extension TransactionDetailsViewModelFactory {
    func createExtrinsViewModels(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> [WalletFormViewBindingProtocol]? {
        guard let address = try? chainAccount.accountId.toAddress(using: chainAccount.chainFormat) else {
            return nil
        }

        var viewModels: [WalletFormViewBindingProtocol] = []

        populateTransactionId(
            in: &viewModels,
            data: data,
            commandFactory: commandFactory,
            locale: locale
        )

        populateSender(
            in: &viewModels,
            address: address,
            commandFactory: commandFactory,
            locale: locale
        )

        populateStatus(into: &viewModels, data: data, locale: locale)
        populateTime(into: &viewModels, data: data, locale: locale)

        if let module = data.peerFirstName {
            let title = R.string.localizable.commonModule(preferredLanguages: locale.rLanguages)
            populateTitleWithDetails(
                into: &viewModels,
                title: title,
                details: module.displayModule
            )
        }

        if let call = data.peerLastName {
            let title = R.string.localizable.commonCall(preferredLanguages: locale.rLanguages)
            populateTitleWithDetails(
                into: &viewModels,
                title: title,
                details: call.displayCall
            )
        }

        let feeTitle = R.string.localizable
            .commonNetworkFee(preferredLanguages: locale.rLanguages)
        populateAmount(into: &viewModels, title: feeTitle, data: data, locale: locale)

        return viewModels
    }

    func createExtrinsicAccessoryViewModel(
        data _: AssetTransactionData,
        commandFactory _: WalletCommandFactoryProtocol,
        locale _: Locale
    ) -> AccessoryViewModelProtocol? {
        nil
    }

    private func populateSender(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        address: String,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable
            .transactionDetailsFrom(preferredLanguages: locale.rLanguages)
        populatePeerViewModel(
            in: &viewModelList,
            title: title,
            address: address,
            commandFactory: commandFactory,
            locale: locale
        )
    }
}
