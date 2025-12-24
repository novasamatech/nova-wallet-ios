import Foundation
import Operation_iOS
import Foundation_iOS

final class PVAddressesPresenter: HardwareWalletAddressesPresenter {
    let wireframe: PVAddressesWireframeProtocol
    let interactor: PVAddressesInteractorInputProtocol
    let type: ParitySignerType

    var account: PolkadotVaultAccount?

    let logger: LoggerProtocol

    init(
        type: ParitySignerType,
        interactor: PVAddressesInteractorInputProtocol,
        wireframe: PVAddressesWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.type = type
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        super.init(viewModelFactory: viewModelFactory)

        self.localizationManager = localizationManager
    }

    func provideDescriptionViewModel() {
        let languages = selectedLocale.rLanguages
        let viewModel = TitleWithSubtitleViewModel(
            title: R.string(preferredLanguages: languages).localizable.paritySignerAddressesTitle(),
            subtitle: R.string(preferredLanguages: languages).localizable.paritySignerAddressesSubtitle(
                type.getName(for: selectedLocale)
            )
        )

        view?.didReceive(descriptionViewModel: viewModel)
    }
}

extension PVAddressesPresenter: HardwareWalletAddressesPresenterProtocol {
    func setup() {
        provideDescriptionViewModel()
        interactor.setup()
    }

    func select(viewModel: ChainAccountViewModelItem) {
        performSelection(of: viewModel, wireframe: wireframe, locale: selectedLocale)
    }

    func proceed() {
        guard let account else { return }

        wireframe.showConfirmation(
            on: view,
            account: account,
            type: type
        )
    }
}

extension PVAddressesPresenter: PVAddressesInteractorOutputProtocol {
    func didReceive(account: PolkadotVaultAccount) {
        self.account = account
    }

    func didReceive(accountId: AccountId) {
        addresses = [
            HardwareWalletAddressModel(
                accountId: accountId,
                scheme: .substrate
            )
        ]

        provideViewModel()
    }

    func didReceive(chains: [DataProviderChange<ChainModel>]) {
        chainList.apply(changes: chains)

        provideViewModel()
    }

    func didReceive(error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)

        logger.error("Did receive error: \(error)")
    }
}

extension PVAddressesPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideDescriptionViewModel()
        }
    }
}
