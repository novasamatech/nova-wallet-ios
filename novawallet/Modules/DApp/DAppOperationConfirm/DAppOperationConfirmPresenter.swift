import Foundation
import BigInt
import SoraFoundation
import SubstrateSdk

final class DAppOperationConfirmPresenter {
    weak var view: DAppOperationConfirmViewProtocol?
    let wireframe: DAppOperationConfirmWireframeProtocol
    let interactor: DAppOperationConfirmInteractorInputProtocol
    let logger: LoggerProtocol?
    let chain: DAppEitherChain

    private(set) weak var delegate: DAppOperationConfirmDelegate?

    let viewModelFactory: DAppOperationConfirmViewModelFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private var confirmationModel: DAppOperationConfirmModel?
    private var feeModel: RuntimeDispatchInfo?
    private var priceData: PriceData?

    init(
        interactor: DAppOperationConfirmInteractorInputProtocol,
        wireframe: DAppOperationConfirmWireframeProtocol,
        delegate: DAppOperationConfirmDelegate,
        viewModelFactory: DAppOperationConfirmViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chain: DAppEitherChain,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.delegate = delegate
        self.viewModelFactory = viewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chain = chain
        self.logger = logger

        self.localizationManager = localizationManager
    }

    private func provideConfirmationViewModel() {
        guard let model = confirmationModel else {
            return
        }

        let viewModel = viewModelFactory.createViewModel(from: model)
        view?.didReceive(confirmationViewModel: viewModel)
    }

    private func provideFeeViewModel() {
        guard let feeModel = feeModel else {
            view?.didReceive(feeViewModel: .loading)
            return
        }

        guard
            let fee = BigUInt(feeModel.fee),
            let feeDecimal = viewModelFactory.convertBalanceToDecimal(fee) else {
            view?.didReceive(feeViewModel: .loading)
            return
        }

        if fee > 0 {
            let viewModel = balanceViewModelFactory.balanceFromPrice(feeDecimal, priceData: priceData)
                .value(for: selectedLocale)
            view?.didReceive(feeViewModel: .loaded(value: viewModel))
        } else {
            view?.didReceive(feeViewModel: .empty)
        }
    }

    private func showConfirmationError(_ error: ErrorContentConvertible) {
        let rejectAction = AlertPresentableAction(
            title: R.string.localizable.commonReject(preferredLanguages: selectedLocale.rLanguages)
        ) { [weak self] in
            self?.interactor.reject()
        }

        let errorContent = error.toErrorContent(for: selectedLocale)

        let viewModel = AlertPresentableViewModel(
            title: errorContent.title,
            message: errorContent.message,
            actions: [rejectAction],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages)
        )

        wireframe.present(viewModel: viewModel, style: .alert, from: view)
    }
}

extension DAppOperationConfirmPresenter: DAppOperationConfirmPresenterProtocol {
    func setup() {
        provideConfirmationViewModel()
        provideFeeViewModel()

        interactor.setup()
    }

    func confirm() {
        interactor.confirm()
    }

    func reject() {
        interactor.reject()
    }

    func activateTxDetails() {
        interactor.prepareTxDetails()
    }

    func showAccountOptions() {
        guard
            let address = confirmationModel?.chainAddress,
            let chain = chain.nativeChain,
            let view = view else {
            return
        }

        wireframe.presentAccountOptions(
            from: view,
            address: address,
            chain: chain,
            locale: selectedLocale
        )
    }
}

extension DAppOperationConfirmPresenter: DAppOperationConfirmInteractorOutputProtocol {
    func didReceive(modelResult: Result<DAppOperationConfirmModel, Error>) {
        switch modelResult {
        case let .success(model):
            confirmationModel = model
        case let .failure(error):
            confirmationModel = nil

            if let contentConvertible = error as? ErrorContentConvertible {
                showConfirmationError(contentConvertible)
            }

            logger?.error("Confirmation error: \(error)")
        }

        provideConfirmationViewModel()
        provideFeeViewModel()
    }

    func didReceive(feeResult: Result<RuntimeDispatchInfo, Error>) {
        switch feeResult {
        case let .success(fee):
            feeModel = fee
        case .failure:
            feeModel = nil

            wireframe.presentFeeStatus(
                on: view,
                locale: selectedLocale
            ) { [weak self] in
                self?.interactor.estimateFee()
            }
        }

        provideFeeViewModel()
    }

    func didReceive(priceResult: Result<PriceData?, Error>) {
        switch priceResult {
        case let .success(priceData):
            self.priceData = priceData
        case let .failure(error):
            priceData = nil

            if !wireframe.present(error: error, from: view, locale: selectedLocale) {
                logger?.error("Price error: \(error)")
            }
        }

        provideFeeViewModel()
    }

    func didReceive(responseResult: Result<DAppOperationResponse, Error>, for request: DAppOperationRequest) {
        switch responseResult {
        case let .success(response):
            delegate?.didReceiveConfirmationResponse(response, for: request)
            wireframe.close(view: view)

        case let .failure(error):
            if error.isWatchOnlySigning {
                guard let view = view else {
                    return
                }

                wireframe.presentNoSigningView(from: view) { [weak self] in
                    self?.interactor.reject()
                }
            } else if error.isHardwareWalletSigningCancelled {
                return
            } else if let notSupportedSigner = error.notSupportedSignerType {
                guard let view = view else {
                    return
                }

                wireframe.presentSignerNotSupportedView(from: view, type: notSupportedSigner) { [weak self] in
                    self?.interactor.reject()
                }
            } else if !wireframe.present(error: error, from: view, locale: selectedLocale) {
                logger?.error("Response error: \(error)")
            }
        }
    }

    func didReceive(txDetailsResult: Result<JSON, Error>) {
        switch txDetailsResult {
        case let .success(txDetails):
            wireframe.showTxDetails(from: view, json: txDetails)
        case let .failure(error):
            if !wireframe.present(error: error, from: view, locale: selectedLocale) {
                logger?.error("Tx details error: \(error)")
            }
        }
    }
}

extension DAppOperationConfirmPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            provideConfirmationViewModel()
            provideFeeViewModel()
        }
    }
}
