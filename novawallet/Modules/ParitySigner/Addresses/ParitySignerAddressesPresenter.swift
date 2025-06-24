import Foundation
import Operation_iOS
import Foundation_iOS
import SubstrateSdk

final class ParitySignerAddressesPresenter: HardwareWalletAddressesBasePresenter {
    let wireframe: ParitySignerAddressesWireframeProtocol
    let interactor: ParitySignerAddressesInteractorInputProtocol
    let type: ParitySignerType
    let walletUpdate: PolkadotVaultWalletUpdate

    let logger: LoggerProtocol

    init(
        walletUpdate: PolkadotVaultWalletUpdate,
        type: ParitySignerType,
        interactor: ParitySignerAddressesInteractorInputProtocol,
        wireframe: ParitySignerAddressesWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.walletUpdate = walletUpdate
        self.type = type
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        super.init(viewModelFactory: viewModelFactory)

        self.localizationManager = localizationManager
    }
}

private extension ParitySignerAddressesPresenter {
    func provideViewModel() {}

    func provideDescriptionViewModel() {
        let languages = selectedLocale.rLanguages
        let viewModel = TitleWithSubtitleViewModel(
            title: R.string.localizable.paritySignerAddressesTitle(preferredLanguages: languages),
            subtitle: R.string.localizable.paritySignerAddressesSubtitle(
                type.getName(for: selectedLocale),
                preferredLanguages: languages
            )
        )

        view?.didReceive(descriptionViewModel: viewModel)
    }
}

extension ParitySignerAddressesPresenter: HardwareWalletAddressesPresenterProtocol {
    func setup() {
        provideDescriptionViewModel()
        interactor.setup()
    }

    func select(viewModel: ChainAccountViewModelItem) {
        performSelection(of: viewModel, wireframe: wireframe, locale: selectedLocale)
    }

    func proceed() {
        wireframe.showConfirmation(on: view, walletUpdate: walletUpdate, type: type)
    }
}

extension ParitySignerAddressesPresenter: ParitySignerAddressesInteractorOutputProtocol {
    func didReceive(chains: [DataProviderChange<ChainModel>]) {
        chainList.apply(changes: chains)

        provideViewModel()
    }
}

extension ParitySignerAddressesPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideDescriptionViewModel()
        }
    }
}
