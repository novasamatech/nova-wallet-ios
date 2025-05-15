import Foundation
import Foundation_iOS

class PayShopBrandsPresenter {
    weak var baseView: PayShopBrandsViewProtocol?
    let baseWireframe: PayShopBrandsWireframeProtocol
    let interactor: PayShopBrandsInteractorInputProtocol
    let viewModelFactory: PayShopBrandViewModelFactoryProtocol
    let logger: LoggerProtocol

    var hasMore: Bool {
        pageNumber < maxPages
    }

    private var maxPages: Int {
        (totalCount ?? 0 + RaiseBrandsRequestInfo.defaultPageSize - 1) / RaiseBrandsRequestInfo.defaultPageSize
    }

    private var totalCount: Int?
    private(set) var pageNumber: Int = 0
    private(set) var brands: [RaiseBrandRemote]?
    private(set) var pendingRequest: RaiseBrandsRequestInfo?

    init(
        interactor: PayShopBrandsInteractorInputProtocol,
        wireframe: PayShopBrandsWireframeProtocol,
        viewModelFactory: PayShopBrandViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.interactor = interactor
        baseWireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.logger = logger
        self.localizationManager = localizationManager
    }

    // MARK: Base interface

    func setBrands(value: [RaiseBrandRemote]?) {
        brands = value
    }

    func setPendingRequest(value: RaiseBrandsRequestInfo?) {
        pendingRequest = value
    }

    // MARK: Presenter Protocol

    func performSetup() {
        fatalError("Must be overriden by subsclass")
    }

    func performLoadMore() {
        fatalError("Must be overriden by subsclass")
    }

    func performLocaleUpdate() {
        guard let brands else {
            return
        }

        provideViewModels(for: brands, loadedMore: false)
    }

    // MARK: Interactor output

    func handle(
        brandList: RaiseListResult<RaiseBrandAttributes>,
        info: RaiseBrandsRequestInfo
    ) {
        logger.debug("Brands: \(brandList.items.count)")

        guard pendingRequest == info else {
            return
        }

        setPendingRequest(value: nil)

        if info.isFirstPage {
            brands = brandList.items
        } else {
            brands = (brands ?? []) + brandList.items
        }

        pageNumber = info.pageIndex
        totalCount = brandList.total

        provideViewModels(for: brandList.items, loadedMore: !info.isFirstPage)
    }

    func handle(error: PayShopBrandsInteractorError) {
        logger.error("Error: \(error)")

        switch error {
        case let .brandsFailed(_, requestInfo):
            guard pendingRequest == requestInfo else {
                return
            }

            setPendingRequest(value: nil)

            baseWireframe.presentRequestStatus(on: baseView, locale: selectedLocale) { [weak self] in
                self?.setPendingRequest(value: requestInfo)
                self?.interactor.requestBrands(for: requestInfo)
            }
        case .raiseSubscriptionFailed:
            break
        }
    }
}

private extension PayShopBrandsPresenter {
    func provideViewModels(for newBrands: [RaiseBrandRemote], loadedMore: Bool) {
        let viewModels = newBrands.map { viewModelFactory.createViewModel(fromBrand: $0, locale: selectedLocale) }

        if loadedMore {
            baseView?.didLoad(viewModels: viewModels)
        } else {
            baseView?.didReload(viewModels: viewModels)
        }
    }
}

extension PayShopBrandsPresenter: PayShopBrandsPresenterProtocol {
    func setup() {
        performSetup()
    }

    func loadMore() {
        performLoadMore()
    }
}

extension PayShopBrandsPresenter: PayShopBrandsInteractorOutputProtocol {
    func didReceive(
        brandList: RaiseListResult<RaiseBrandAttributes>,
        info: RaiseBrandsRequestInfo
    ) {
        handle(brandList: brandList, info: info)
    }

    func didReceive(error: PayShopBrandsInteractorError) {
        handle(error: error)
    }
}

extension PayShopBrandsPresenter: Localizable {
    func applyLocalization() {
        guard let baseView, baseView.isSetup else { return }

        performLocaleUpdate()
    }
}
