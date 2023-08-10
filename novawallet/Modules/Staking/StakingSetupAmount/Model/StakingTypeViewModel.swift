struct StakingTypeViewModel {
    enum TypeModel {
        case recommended(RecommendedStakingTypeViewModel)
        case direct(DirectStakingTypeViewModel.ValidatorModel)
        case pools(PoolStakingTypeViewModel.PoolAccountModel)
    }

    let type: TypeModel
    let maxApy: String
    let shouldEnableSelection: Bool
}

struct RecommendedStakingTypeViewModel {
    let title: String
    let subtitle: String
}
