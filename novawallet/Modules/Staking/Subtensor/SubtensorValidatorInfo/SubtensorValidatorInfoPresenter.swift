import Foundation
import Foundation_iOS

final class SubtensorValidatorInfoPresenter {
    weak var view: SubtensorValidatorInfoViewProtocol?

    let target: SubtensorStakeTarget
    let hotkey: AccountId
    let chain: ChainModel
    let interactor: SubtensorValInfoInteractorInputProtocol
    let wireframe: SubtensorValidatorInfoWireframeProtocol
    let viewModelFactory: SubtensorValidatorInfoViewModelFactory

    private var detail: SubtensorValidatorDirectoryItem?
    private var needsChainDetail: Bool
    private var annualRate: LoadableViewModelState<Decimal?> = .loading
    private var alphaPrice: LoadableViewModelState<Balance?> = .loading
    private var coverage: LoadableViewModelState<SubtensorValidatorCoverage?> = .loading
    private var price: PriceData?

    init(
        target: SubtensorStakeTarget,
        hotkey: AccountId,
        chain: ChainModel,
        detail: SubtensorValidatorDirectoryItem?,
        needsChainDetail: Bool,
        interactor: SubtensorValInfoInteractorInputProtocol,
        wireframe: SubtensorValidatorInfoWireframeProtocol,
        viewModelFactory: SubtensorValidatorInfoViewModelFactory,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.target = target
        self.hotkey = hotkey
        self.chain = chain
        self.detail = detail
        self.needsChainDetail = needsChainDetail
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

private extension SubtensorValidatorInfoPresenter {
    func provideViewModel() {
        let input = SubtensorValidatorInfoInput(
            target: target,
            hotkey: hotkey,
            detail: detail,
            needsChainDetail: needsChainDetail,
            annualRate: annualRate,
            alphaPrice: alphaPrice,
            price: price,
            coverage: coverage
        )

        view?.didReceive(viewModel: viewModelFactory.createViewModel(for: input, locale: selectedLocale))
    }

    func seed(from snapshot: SubtensorValidatorInfoSnapshot) {
        if let annualRate = snapshot.annualRate.value {
            self.annualRate = .loaded(value: annualRate)
        }

        if let alphaPrice = snapshot.alphaPrice.value {
            self.alphaPrice = .loaded(value: alphaPrice)
        }
    }

    func loadDetail() {
        view?.didStartLoading()
        interactor.loadDetail()
    }
}

extension SubtensorValidatorInfoPresenter: SubtensorValidatorInfoPresenterProtocol {
    func setup() {
        seed(from: interactor.cachedSnapshot())
        provideViewModel()

        interactor.setup()

        if detail == nil || needsChainDetail {
            loadDetail()
        }
    }

    func presentAccountOptions() {
        if
            let view = view,
            let address = try? hotkey.toAddress(using: chain.chainFormat) {
            wireframe.presentAccountOptions(
                from: view,
                address: address,
                chain: chain,
                locale: selectedLocale
            )
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
    func didReceive(coverage: SubtensorValidatorCoverage?) {
        self.coverage = .loaded(value: coverage)
        provideViewModel()
    }

    func didReceive(detail: SubtensorValidatorDirectoryItem) {
        view?.didStopLoading()

        self.detail = detail
        needsChainDetail = false
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
