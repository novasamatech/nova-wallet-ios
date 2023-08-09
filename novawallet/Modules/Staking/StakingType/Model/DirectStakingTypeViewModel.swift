struct DirectStakingTypeViewModel {
    let title: String
    let subtile: String
    let validator: ValidatorModel?

    struct ValidatorModel {
        let title: String
        let subtitle: String
        let isRecommended: Bool
        let count: String
    }
}
