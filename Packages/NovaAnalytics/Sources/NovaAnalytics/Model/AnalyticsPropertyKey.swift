import Foundation

public enum AnalyticsPropertyKey: String, CaseIterable {
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
    case nftCountBucket = "nft_count_bucket"
    case chain
    case target
    case mode
    case flow
    case kind
    case outcome
    case endpoint
    case walletType = "wallet_type"
    case netuid
    case selectionMethod = "selection_method"
    case validatorSource = "validator_source"
    case hasNewBadge = "has_new_badge"
    case priceMoved = "price_moved"
    case retryable
    case action
    case value
    case period
    case chartState = "chart_state"
    case rewardsState = "rewards_state"
    case hasHold = "has_hold"
    case hasLock = "has_lock"
    case hasLocked = "has_locked"
    case hotkeyCountBucket = "hotkey_count_bucket"
    case validatorsCountBucket = "validators_count_bucket"
    case positionsCountBucket = "positions_count_bucket"
    case hasRoot = "has_root"
    case claimedZero = "claimed_zero"
    case warning
    case sort
    case hideThinPools = "hide_thin_pools"
    case unusualApyFilter = "unusual_apy_filter"
}
