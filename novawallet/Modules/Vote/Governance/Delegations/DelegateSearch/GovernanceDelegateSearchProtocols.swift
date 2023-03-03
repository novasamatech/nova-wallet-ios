protocol GovernanceDelegateSearchViewProtocol: TableSearchViewProtocol {
    func didReceive(viewModels: [GovernanceDelegateTableViewCell.Model])
}

protocol GovernanceDelegateSearchPresenterProtocol: TableSearchPresenterProtocol {}

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

protocol GovernanceDelegateSearchWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable {}
