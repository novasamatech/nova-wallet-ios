protocol DelegateReferendumsModelFactoryProtocol {
    func createReferendumsViewModel(input: ReferendumsModelFactoryInput) -> [ReferendumsCellViewModel]
    func createLoadingViewModel() -> [ReferendumsSection]
}
