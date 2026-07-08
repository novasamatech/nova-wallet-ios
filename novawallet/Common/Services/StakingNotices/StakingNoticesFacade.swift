import Foundation

enum StakingNoticesFacade {
    static let sharedProvider: StakingNoticesProviding = StakingNoticesProvider(
        url: ApplicationConfig.shared.stakingNoticesURL
    )
}
