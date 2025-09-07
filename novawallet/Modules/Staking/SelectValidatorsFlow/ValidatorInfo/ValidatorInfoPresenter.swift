import Foundation
import Foundation_iOS

final class ValidatorInfoPresenter {
    weak var view: ValidatorInfoViewProtocol?
    let interactor: ValidatorInfoInteractorInputProtocol
    let wireframe: ValidatorInfoWireframeProtocol

    private let viewModelFactory: ValidatorInfoViewModelFactoryProtocol
    private let chain: ChainModel
    private let logger: LoggerProtocol?

    private(set) var validatorInfoResult: Result<ValidatorInfoProtocol?, Error>?
    private(set) var priceDataResult: Result<PriceData?, Error>?

    init(
        interactor: ValidatorInfoInteractorInputProtocol,
        wireframe: ValidatorInfoWireframeProtocol,
        viewModelFactory: ValidatorInfoViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        chain: ChainModel,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.chain = chain
        self.logger = logger
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let validatorInfoResult = self.validatorInfoResult else {
            view?.didRecieve(state: .empty)
            return
        }

        do {
            let priceData = try priceDataResult?.get()

            if let validatorInfo = try validatorInfoResult.get() {
                let viewModel = viewModelFactory.createViewModel(
                    from: validatorInfo,
                    priceData: priceData,
                    locale: selectedLocale
                )

                view?.didRecieve(state: .validatorInfo(viewModel))
            } else {
                view?.didRecieve(state: .empty)
            }

        } catch {
            logger?.error("Did receive error: \(error)")

            let error = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonErrorNoDataRetrieved()

            view?.didRecieve(state: .error(error))
        }
    }
}

extension ValidatorInfoPresenter: ValidatorInfoPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func reload() {
        interactor.reload()
    }

    func presentAccountOptions() {
        if let view = view, let validatorInfo = try? validatorInfoResult?.get() {
            wireframe.presentAccountOptions(
                from: view,
                address: validatorInfo.address,
                chain: chain,
                locale: selectedLocale
            )
        }
    }

    func presentTotalStake() {
        guard let validatorInfo = try? validatorInfoResult?.get() else { return }

        let priceData = try? priceDataResult?.get()

        wireframe.showStakingAmounts(
            from: view,
            items: viewModelFactory.createStakingAmountsViewModel(
                from: validatorInfo,
                priceData: priceData
            )
        )
    }

    func presentIdentityItem(_ value: ValidatorInfoViewModel.IdentityItemValue) {
        guard case let .link(value, tag) = value, let view = view else {
            return
        }

        wireframe.presentIdentityItem(
            from: view,
            tag: tag,
            value: value,
            locale: selectedLocale
        )
    }
}

extension ValidatorInfoPresenter: ValidatorInfoInteractorOutputProtocol {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        priceDataResult = result
        updateView()
    }

    func didStartLoadingValidatorInfo() {
        view?.didRecieve(state: .loading)
    }

    func didReceiveValidatorInfo(result: Result<ValidatorInfoProtocol?, Error>) {
        validatorInfoResult = result
        updateView()
    }
}

extension ValidatorInfoPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            updateView()
        }
    }
}
