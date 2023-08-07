struct DirectStakingTypeViewModel {
    let title: String
    let subtile: String
    let nominatorModel: NominatorModel?

    struct NominatorModel {
        let title: String
        let subtitle: String
        let isRecommended: Bool
        let count: String
    }
}
