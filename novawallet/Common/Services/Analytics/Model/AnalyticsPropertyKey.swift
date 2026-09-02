import Foundation

/// The 32 wire property keys. Android's 33rd key, `banner_title`, has no case: `Banner`
/// carries `id`, `background`, `image`, `clipsToBounds` and `actionLink`, and no title.
enum AnalyticsPropertyKey: String, CaseIterable {
    case isFirstLaunch = "is_first_launch"
    case durationBucket = "duration_bucket"
    case source
    case method
    case lastStep = "last_step"
    case featureId = "feature_id"
    case tab
    case asset
    case assetIn = "asset_in"
    case assetOut = "asset_out"
    case network
    case networkIn = "network_in"
    case networkOut = "network_out"
    case destinationNetwork = "destination_network"
    case assetCategory = "asset_category"
    case assetInCategory = "asset_in_category"
    case assetOutCategory = "asset_out_category"
    case amountBucket = "amount_bucket"
    case slippageBucket = "slippage_bucket"
    case isCrossChain = "is_cross_chain"
    case reason
    case stage
    case stakingType = "staking_type"
    case voteDirection = "vote_direction"
    case convictionLevel = "conviction_level"
    case dappHost = "dapp_host"
    case isKnownDapp = "is_known_dapp"
    case provider
    case bannerId = "banner_id"
    case screen
    case nftCount = "nft_count"
    case chain
}
