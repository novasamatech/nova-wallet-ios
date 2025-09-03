import Foundation
import Foundation_iOS
import SubstrateSdk

final class ChangeWatchOnlyPresenter {
    weak var view: ChangeWatchOnlyViewProtocol?
    let wireframe: ChangeWatchOnlyWireframeProtocol
    let interactor: ChangeWatchOnlyInteractorInputProtocol

    private var partialAddress: AccountAddress?

    private lazy var iconGenerator = PolkadotIconGenerator()

    let chain: ChainModel
    let logger: LoggerProtocol

    init(
        interactor: ChangeWatchOnlyInteractorInputProtocol,
        wireframe: ChangeWatchOnlyWireframeProtocol,
        chain: ChainModel,
        logger: LoggerProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.chain = chain
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func getAccountId() -> AccountId? {
        try? partialAddress?.toAccountId(using: chain.chainFormat)
    }

    private func provideAddressStateViewModel() {
        if
            let accountId = getAccountId(),
            let icon = try? iconGenerator.generateFromAccountId(accountId) {
            let iconViewModel = DrawableIconViewModel(icon: icon)
            let viewModel = AccountFieldStateViewModel(icon: iconViewModel)
            view?.didReceiveAddressState(viewModel: viewModel)
        } else {
            let viewModel = AccountFieldStateViewModel(icon: nil)
            view?.didReceiveAddressState(viewModel: viewModel)
        }
    }

    private func provideAddressInputViewModel() {
        let value = partialAddress ?? ""

        let title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonChainAddressTitle(
            chain.name
        )

        let inputViewModel = InputViewModel.createAccountInputViewModel(
            for: value,
            title: title
        )

        view?.didReceiveAddressInput(viewModel: inputViewModel)
    }
}

extension ChangeWatchOnlyPresenter: ChangeWatchOnlyPresenterProtocol {
    func setup() {
        provideAddressStateViewModel()
        provideAddressInputViewModel()
    }

    func updateAddress(_ partialAddress: String) {
        self.partialAddress = partialAddress

        provideAddressStateViewModel()
    }

    func performScan() {
        wireframe.showAddressScan(from: view, delegate: self, context: nil)
    }

    func proceed() {
        if let address = partialAddress, getAccountId() != nil {
            interactor.save(address: address)
        } else if let view = view {
            wireframe.presentInvalidAddress(from: view, chainName: chain.name, locale: selectedLocale)
        }
    }
}

extension ChangeWatchOnlyPresenter: ChangeWatchOnlyInteractorOutputProtocol {
    func didSaveAddress(_: AccountAddress) {
        wireframe.complete(view: view)
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: selectedLocale)
        logger.error("Did receive error: \(error)")
    }
}

extension ChangeWatchOnlyPresenter: AddressScanDelegate {
    func addressScanDidReceiveRecepient(address: AccountAddress, context _: AnyObject?) {
        wireframe.hideAddressScan(from: view)

        partialAddress = address
        provideAddressStateViewModel()
        provideAddressInputViewModel()
    }
}

extension ChangeWatchOnlyPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideAddressInputViewModel()
        }
    }
}
