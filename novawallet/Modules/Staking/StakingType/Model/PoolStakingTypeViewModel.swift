struct PoolStakingTypeViewModel {
    let title: String
    let subtile: String
    let poolAccount: PoolAccountModel?
    let canChangePool: Bool

    struct PoolAccountModel {
        let icon: ImageViewModelProtocol?
        let title: String
        let subtitle: String?
        let isRecommended: Bool
    }
}
