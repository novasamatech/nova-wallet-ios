import Foundation
import Operation_iOS
import Foundation_iOS

final class ParitySignerAddressesPresenter: HardwareWalletAddressesPresenter {
    let wireframe: ParitySignerAddressesWireframeProtocol
    let interactor: ParitySignerAddressesInteractorInputProtocol
    let type: ParitySignerType

    let logger: LoggerProtocol

    init(
        type: ParitySignerType,
        interactor: ParitySignerAddressesInteractorInputProtocol,
        wireframe: ParitySignerAddressesWireframeProtocol,
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
        // PV supports only substrate now but evm will come soon
        guard let accountId = addresses.first?.accountId else {
            return
        }

        wireframe.showConfirmation(on: view, accountId: accountId, type: type)
    }
}

extension ParitySignerAddressesPresenter: ParitySignerAddressesInteractorOutputProtocol {
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

extension ParitySignerAddressesPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideDescriptionViewModel()
        }
    }
}
