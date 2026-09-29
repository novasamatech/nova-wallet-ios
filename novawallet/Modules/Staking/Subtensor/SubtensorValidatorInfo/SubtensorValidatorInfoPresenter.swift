import Foundation
import Foundation_iOS

final class SubtensorValidatorInfoPresenter {
    weak var view: SubtensorValidatorInfoViewProtocol?

    let target: SubtensorStakeTarget
    let hotkey: AccountId
    let interactor: SubtensorValInfoInteractorInputProtocol
    let wireframe: SubtensorValidatorInfoWireframeProtocol
    let viewModelFactory: SubtensorValidatorInfoViewModelFactory
    let logger: LoggerProtocol

    private var detail: SubtensorValidatorDetail?
    private var annualRate: LoadableViewModelState<Decimal?> = .loading
    private var alphaPrice: LoadableViewModelState<Balance?> = .loading
    private var price: PriceData?

    init(
        target: SubtensorStakeTarget,
        hotkey: AccountId,
        detail: SubtensorValidatorDetail?,
        interactor: SubtensorValInfoInteractorInputProtocol,
        wireframe: SubtensorValidatorInfoWireframeProtocol,
        viewModelFactory: SubtensorValidatorInfoViewModelFactory,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.target = target
        self.hotkey = hotkey
        self.detail = detail
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }
}

private extension SubtensorValidatorInfoPresenter {
    func provideViewModel() {
        let input = SubtensorValidatorInfoInput(
            target: target,
            hotkey: hotkey,
            detail: detail,
            annualRate: annualRate,
            alphaPrice: alphaPrice,
            price: price
        )

        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: input, locale: selectedLocale))
    }

    func loadDetail() {
        view?.didStartLoading()
        interactor.loadDetail()
    }
}

extension SubtensorValidatorInfoPresenter: SubtensorValidatorInfoPresenterProtocol {
    func setup() {
        provideViewModel()

        interactor.setup()

        if detail == nil {
            loadDetail()
        }
    }

    func showStakeInfo() {
        wireframe.showSubtensorInfo(.totalStaked(isRoot: target.isRoot), from: view)
    }

    func showTakeInfo() {
        wireframe.showSubtensorInfo(.validatorTake, from: view)
    }
}

extension SubtensorValidatorInfoPresenter: SubtensorValInfoInteractorOutputProtocol {
    func didReceive(detail: SubtensorValidatorDetail) {
        view?.didStopLoading()

        self.detail = detail
        provideViewModel()
    }

    func didFailDetail(_: Error) {
        view?.didStopLoading()

        wireframe.presentRequestStatus(
            on: view,
            locale: selectedLocale,
            retryAction: { [weak self] in
                self?.loadDetail()
            },
            skipAction: { [weak self] in
                self?.wireframe.close(view: self?.view)
            }
        )
    }

    func didReceive(annualRate: Decimal?) {
        self.annualRate = .loaded(value: annualRate)
        provideViewModel()
    }

    func didReceive(alphaPrice: Balance?) {
        self.alphaPrice = .loaded(value: alphaPrice)
        provideViewModel()
    }

    func didReceive(price: PriceData?) {
        self.price = price
        provideViewModel()
    }
}

extension SubtensorValidatorInfoPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            provideViewModel()
        }
    }
}
