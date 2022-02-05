import Foundation
import CommonWallet
import SoraFoundation

final class TransferConfirmConfigurator {
    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            viewModelFactory.commandFactory
        }

        set {
            viewModelFactory.commandFactory = newValue
        }
    }

    let viewModelFactory: TransferConfirmViewModelFactory
    let localizationManager: LocalizationManagerProtocol

    init(
        chainAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        feeViewModelFactory: BalanceViewModelFactoryProtocol?,
        localizationManager: LocalizationManagerProtocol
    ) {
        viewModelFactory = TransferConfirmViewModelFactory(
            chainAccount: chainAccount,
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory,
            feeViewModelFactory: feeViewModelFactory
        )

        self.localizationManager = localizationManager
    }

    func configure(builder: TransferConfirmationModuleBuilderProtocol) {
        let title = LocalizableResource { locale in
            R.string.localizable.commonConfirmTitle(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(localizableTitle: title)
            .with(accessoryViewType: .onlyActionBar)
            .with(completion: .hide)
            .with(viewModelFactoryOverriding: viewModelFactory)
            .with(definitionFactory: WalletFearlessDefinitionFactory())
            .with(accessoryViewFactory: TransferConfirmAccessoryViewFactory.self)
    }
}
