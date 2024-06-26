import Foundation
import SoraFoundation
import Operation_iOS

final class GenericLedgerWalletPresenter: HardwareWalletAddressesPresenter {
    let wireframe: GenericLedgerWalletWireframeProtocol
    let interactor: GenericLedgerWalletInteractorInputProtocol
    let logger: LoggerProtocol

    init(
        interactor: GenericLedgerWalletInteractorInputProtocol,
        wireframe: GenericLedgerWalletWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        
        super.init(viewModelFactory: viewModelFactory)
    }
    
    private func provideDescriptionViewModel() {
        let languages = selectedLocale.rLanguages
        let viewModel = TitleWithSubtitleViewModel(
            title: R.string.localizable.paritySignerAddressesTitle(preferredLanguages: languages),
            subtitle: ""
        )

        view?.didReceive(descriptionViewModel: viewModel)
    }
}

extension GenericLedgerWalletPresenter: HardwareWalletAddressesPresenterProtocol {
    func setup() {
        provideDescriptionViewModel()
        interactor.setup()
    }
    
    func select(viewModel: ChainAccountViewModelItem) {
        performSelection(of: viewModel, wireframe: wireframe, locale: selectedLocale)
    }
    
    func proceed() {
        
    }
}

extension GenericLedgerWalletPresenter: GenericLedgerWalletInteractorOutputProtocol {
    func didReceive(account: LedgerAccount) {
        accountId = try? account.address.toAccountId()
        
        provideViewModel()
    }
    
    func didReceiveAccountConfirmation() {
        
    }
    
    func didReceiveChains(changes: [DataProviderChange<ChainModel>]) {
        chainList.apply(changes: chains)

        provideViewModel()
    }
    
    func didReceive(error: GenericWalletConfirmInteractorError) {
        logger.error("Error: \(error)")
        
        // TODO: display error here
    }
}

extension GenericLedgerWalletPresenter: Localizable {
    func applyLocalization() {
        if let view, view.isSetup {
            provideDescriptionViewModel()
        }
    }
}
