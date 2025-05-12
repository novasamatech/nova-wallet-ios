import Operation_iOS

protocol DelegatedAccountsRepositoryProtocol {
    func fetchDelegatedAccountsWrapper(
        for delegators: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: [DiscoveredDelegatedAccountProtocol]]>
}
