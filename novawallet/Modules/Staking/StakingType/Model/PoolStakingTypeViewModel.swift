struct PoolStakingTypeViewModel {
    let title: String
    let subtile: String
    let poolAccount: PoolAccountModel?

    struct PoolAccountModel {
        let icon: ImageViewModelProtocol?
        let title: String
        let subtitle: String?
    }
}
