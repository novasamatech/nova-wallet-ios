import Foundation
import Operation_iOS
import Foundation_iOS

final class PayShopPresenter: PayShopBrandsPresenter {
    private var raiseCards: [String: RaiseCardLocal]? {
        didSet {
            updateView()
        }
    }

    var view: PayShopViewProtocol? {
        baseView as? PayShopViewProtocol
    }

    var wireframe: PayShopWireframeProtocol? {
        baseWireframe as? PayShopWireframeProtocol
    }

    var listInteractor: PayShopInteractorInputProtocol? {
        interactor as? PayShopInteractorInputProtocol
    }

    let listViewModelFactory: PayShopViewModelFactoryProtocol

    init(
        interactor: PayShopInteractorInputProtocol,
        wireframe: PayShopWireframeProtocol,
        brandModelFactory: PayShopBrandViewModelFactoryProtocol,
        listViewModelFactory: PayShopViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.listViewModelFactory = listViewModelFactory

        super.init(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: brandModelFactory,
            localizationManager: localizationManager,
            logger: logger
        )
    }

    // MARK: Subclass overridings

    override func performSetup() {
        provideAvailabilityViewModel()

        listInteractor?.setup()

        let request = RaiseBrandsRequestInfo()
        setPendingRequest(value: request)

        interactor.requestBrands(for: request)
    }

    override func performLoadMore() {
        guard
            pendingRequest == nil,
            hasMore
        else {
            return
        }

        let nextPage = pageNumber + 1

        let request = RaiseBrandsRequestInfo(pageIndex: nextPage)
        setPendingRequest(value: request)

        interactor.requestBrands(for: request)
    }

    override func performLocaleUpdate() {
        super.performLocaleUpdate()

        updateView()
    }

    override func handle(brandList: RaiseListResult<RaiseBrandAttributes>, info: RaiseBrandsRequestInfo) {
        super.handle(brandList: brandList, info: info)

        updateView()
    }
}

private extension PayShopPresenter {
    func selectRemote(brand: RaiseBrandRemote) {
        wireframe?.proceedWithBrand(from: view, brand: brand)
    }

    func updateView() {
        provideAvailabilityViewModel()
    }

    func provideAvailabilityViewModel() {
        let availabilityViewModel = listViewModelFactory.createAvailabilityViewModel(
            from: brands ?? [],
            locale: selectedLocale
        )

        view?.didReceive(availabilityViewModel: availabilityViewModel)
    }
}

extension PayShopPresenter: PayShopPresenterProtocol {
    func select(brand: PayShopBrandViewModel) {
        guard
            let remoteBrand = brands?.first(where: { $0.identifier == brand.identifier })
        else {
            return
        }

        selectRemote(brand: remoteBrand)
    }

    func activateSearch() {
        wireframe?.showSearch(from: view) { [weak self] brand in
            guard let self else { return }

            wireframe?.proceedWithBrand(from: view, brand: brand)
        }
    }

    func activatePreviousPayments() {
        wireframe?.showPreviousPayments(from: view)
    }

    func onAppear() {
        listInteractor?.refresh()
    }
}

extension PayShopPresenter: PayShopInteractorOutputProtocol {
    func didReceive(raiseCardsChanges: [DataProviderChange<RaiseCardLocal>]) {
        guard !raiseCardsChanges.isEmpty else {
            return
        }

        raiseCards = raiseCardsChanges.mergeToDict(raiseCards ?? [:])
    }
}
