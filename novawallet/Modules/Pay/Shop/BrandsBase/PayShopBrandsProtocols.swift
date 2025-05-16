import Foundation

protocol PayShopBrandsViewProtocol: ControllerBackedProtocol {
    func didReload(viewModels: [PayShopBrandViewModel], hasMore: Bool)
    func didLoad(viewModels: [PayShopBrandViewModel], hasMore: Bool)
}

protocol PayShopBrandsPresenterProtocol: AnyObject {
    func setup()
    func loadMore()
}

protocol PayShopBrandsInteractorInputProtocol: AnyObject {
    func requestBrands(for info: RaiseBrandsRequestInfo)
}

protocol PayShopBrandsInteractorOutputProtocol: AnyObject {
    func didReceive(
        brandList: RaiseListResult<RaiseBrandAttributes>,
        info: RaiseBrandsRequestInfo
    )

    func didReceive(error: PayShopBrandsInteractorError)
}

protocol PayShopBrandsWireframeProtocol: AlertPresentable, CommonRetryable {}

enum PayShopBrandsInteractorError: Error {
    case brandsFailed(Error, RaiseBrandsRequestInfo)
    case raiseSubscriptionFailed(Error)
}
