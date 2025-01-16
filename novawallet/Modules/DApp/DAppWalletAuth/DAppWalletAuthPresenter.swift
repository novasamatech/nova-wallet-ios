import Foundation
import Foundation_iOS

final class DAppWalletAuthPresenter {
    weak var view: DAppWalletAuthViewProtocol?
    let wireframe: DAppWalletAuthWireframeProtocol
    let interactor: DAppWalletAuthInteractorInputProtocol
    let viewModelFactory: DAppWalletAuthViewModelFactoryProtocol
    let logger: LoggerProtocol

    private var selectedWallet: MetaAccountModel
    private var totalWalletValue: Decimal?
    private var request: DAppAuthRequest

    weak var delegate: DAppAuthDelegate?

    init(
        request: DAppAuthRequest,
        delegate: DAppAuthDelegate,
        viewModelFactory: DAppWalletAuthViewModelFactoryProtocol,
        interactor: DAppWalletAuthInteractorInputProtocol,
        wireframe: DAppWalletAuthWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.request = request
        selectedWallet = request.wallet
        self.delegate = delegate
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func complete(with result: Bool) {
        let response = DAppAuthResponse(approved: result, wallet: selectedWallet)
        delegate?.didReceiveAuthResponse(response, for: request)
        wireframe.close(from: view)
    }

    private func updateView() {
        guard
            let viewModel = viewModelFactory.createViewModel(
                from: request,
                wallet: selectedWallet,
                totalWalletValue: totalWalletValue,
                locale: selectedLocale
            ) else {
            return
        }

        view?.didReceive(viewModel: viewModel)
    }
}

extension DAppWalletAuthPresenter: DAppWalletAuthPresenterProtocol {
    func setup() {
        updateView()

        interactor.setup()
        interactor.apply(wallet: selectedWallet)
    }

    func approve() {
        complete(with: true)
    }

    func reject() {
        complete(with: false)
    }

    func selectWallet() {
        wireframe.showWalletChoose(
            from: view,
            selectedWalletId: selectedWallet.metaId,
            delegate: self
        )
    }

    func showNetworks() {
        wireframe.showNetworksResolution(
            from: view,
            requiredResolution: request.requiredChains,
            optionalResolution: request.optionalChains
        )
    }
}

extension DAppWalletAuthPresenter: DAppWalletAuthInteractorOutputProtocol {
    func didFetchTotalValue(_ value: Decimal, wallet: MetaAccountModel) {
        logger.debug("Did receive total value: \(value)")

        guard wallet.metaId == selectedWallet.metaId else {
            return
        }

        totalWalletValue = value

        updateView()
    }

    func didReceive(error: BalancesStoreError) {
        // ignore the because a user can't fix storage problems
        logger.error("Did receive error: \(error)")
    }
}

extension DAppWalletAuthPresenter: WalletsChooseDelegate {
    func walletChooseDidSelect(item: ManagedMetaAccountModel) {
        wireframe.closeWalletChoose(on: view) { [weak self] in
            self?.selectedWallet = item.info
            self?.totalWalletValue = nil

            self?.updateView()

            self?.interactor.apply(wallet: item.info)
        }
    }
}

extension DAppWalletAuthPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
