struct PoolStakingTypeViewModel {
    let title: String
    let subtile: String
    let poolModel: PoolModel?

    struct PoolModel {
        let icon: ImageViewModelProtocol?
        let title: String
        let subtitle: String?
    }
}
