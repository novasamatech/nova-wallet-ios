protocol GovernanceDelegateSearchViewProtocol: TableSearchViewProtocol {
    func didReceive(viewModel: TableSearchResultViewModel<AddDelegationViewModel>)
}

protocol GovernanceDelegateSearchPresenterProtocol: TableSearchPresenterProtocol {
    func presentResult(for address: AccountAddress)
}

protocol GovernanceDelegateSearchInteractorInputProtocol: AnyObject {
    func setup()
    func refreshDelegates()
    func remakeSubscriptions()
    func performDelegateSearch(accountId: AccountId)
}

protocol GovernanceDelegateSearchInteractorOutputProtocol: AnyObject {
    func didReceiveIdentity(_ identity: AccountIdentity?, for accountId: AccountId)
    func didReceiveDelegates(_ delegates: [AccountAddress: GovernanceDelegateLocal])
    func didReceiveMetadata(_ metadata: [GovernanceDelegateMetadataRemote]?)
    func didReceiveError(_ error: GovernanceDelegateSearchError)
}

protocol GovernanceDelegateSearchWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {
    func showInfo(from view: GovernanceDelegateSearchViewProtocol?, delegate: GovernanceDelegateLocal)
}
