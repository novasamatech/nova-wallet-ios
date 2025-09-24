protocol DelegateReferendumsModelFactoryProtocol {
    func createReferendumsViewModel(
        params: ReferendumsModelFactoryParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> [ReferendumsCellViewModel]

    func createLoadingViewModel() -> [ReferendumsCellViewModel]
}
