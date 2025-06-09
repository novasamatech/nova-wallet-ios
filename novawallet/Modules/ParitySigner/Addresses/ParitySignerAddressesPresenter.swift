import Foundation
import Operation_iOS
import Foundation_iOS
import SubstrateSdk

final class ParitySignerAddressesPresenter: HardwareWalletAddressesPresenter {
    let wireframe: ParitySignerAddressesWireframeProtocol
    let interactor: ParitySignerAddressesInteractorInputProtocol
    let type: ParitySignerType
    let walletFormat: ParitySignerWalletFormat

    let logger: LoggerProtocol

    init(
        walletFormat: ParitySignerWalletFormat,
        type: ParitySignerType,
        interactor: ParitySignerAddressesInteractorInputProtocol,
        wireframe: ParitySignerAddressesWireframeProtocol,
        viewModelFactory: ChainAccountViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.walletFormat = walletFormat
        self.type = type
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger

        super.init(viewModelFactory: viewModelFactory)

        self.localizationManager = localizationManager
    }
}

private extension ParitySignerAddressesPresenter {
    func setupAddresses() {
        do {
            switch walletFormat {
            case let .single(single):
                addresses = [
                    HardwareWalletAddressModel(
                        accountId: single.substrateAccountId,
                        scheme: .substrate
                    )
                ]
            case let .rootKeys(rootKeys):
                let substrateAccountId = try rootKeys.substrate.publicKeyData.publicKeyToAccountId()
                let ethereumAccountId = try rootKeys.ethereum.publicKeyData.ethereumAddressFromPublicKey()

                addresses = [
                    HardwareWalletAddressModel(
                        accountId: substrateAccountId,
                        scheme: .substrate
                    ),
                    HardwareWalletAddressModel(
                        accountId: ethereumAccountId,
                        scheme: .evm
                    )
                ]
            }
        } catch {
            logger.error("Address setup error: \(error)")
        }
    }

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
        setupAddresses()
        provideDescriptionViewModel()
        interactor.setup()
    }

    func select(viewModel: ChainAccountViewModelItem) {
        performSelection(of: viewModel, wireframe: wireframe, locale: selectedLocale)
    }

    func proceed() {
        wireframe.showConfirmation(on: view, walletFormat: walletFormat, type: type)
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
