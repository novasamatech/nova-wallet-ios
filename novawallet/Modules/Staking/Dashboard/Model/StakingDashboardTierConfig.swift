import Foundation

/// Static config for chains demoted from the dashboard's main `inactive` (offer) list
/// into the `More Options` screen.
///
/// Behaviour:
/// - Chains in this set are routed into `more` instead of `inactive` by `StakingDashboardBuilder`.
/// - Existing user stakes are unaffected — `active` classification happens earlier in the builder.
/// - This is intentionally a code-side constant, not a remote-config value. Demoting/promoting
///   a chain is a slow-changing structural decision.
enum StakingDashboardTierConfig {
    static let demotedChainIds: Set<ChainModel.Id> = [
        KnowChainId.vara,
        KnowChainId.zeitgeist,
        KnowChainId.moonriver,
        KnowChainId.alephZero,
        KnowChainId.polkadex,
        KnowChainId.ternoa,
        KnowChainId.mantaAtlantic
    ]
}
