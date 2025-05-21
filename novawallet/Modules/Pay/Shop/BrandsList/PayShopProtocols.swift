import Operation_iOS

protocol PayShopViewProtocol: PayShopBrandsViewProtocol {
    func didReceive(availabilityViewModel: PayShopAvailabilityViewModel)
}

protocol PayShopPresenterProtocol: PayShopBrandsPresenterProtocol {
    func activateSearch()
    func select(brand: PayShopBrandViewModel)
    func activatePreviousPayments()
    func onAppear()
}

protocol PayShopInteractorInputProtocol: PayShopBrandsInteractorInputProtocol {
    func setup()
    func refresh()
}

protocol PayShopInteractorOutputProtocol: PayShopBrandsInteractorOutputProtocol {
    func didReceive(raiseCardsChanges: [DataProviderChange<RaiseCardLocal>])
}

typealias PayShopBrandSelectionClosure = (RaiseBrandRemote) -> Void

protocol PayShopWireframeProtocol: PayShopBrandsWireframeProtocol {
    func proceedWithBrand(from view: PayShopViewProtocol?, brand: RaiseBrandRemote)
    func showPreviousPayments(from view: PayShopViewProtocol?)
    func showSearch(from view: PayShopViewProtocol?, onComplete: @escaping PayShopBrandSelectionClosure)
}
