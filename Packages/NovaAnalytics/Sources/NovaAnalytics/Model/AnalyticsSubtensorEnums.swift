import Foundation

public enum StakingAnalyticsTarget: String, CaseIterable, AnalyticsPropertyConvertible {
    case root
    case subnet
}

public enum StakingMode: String, CaseIterable, AnalyticsPropertyConvertible {
    case newPosition = "new_position"
    case addStake = "add_stake"
    case buyMore = "buy_more"
}

public enum UnstakeMode: String, CaseIterable, AnalyticsPropertyConvertible {
    case partial
    case full
}

public enum StakingAnalyticsSelectionMethod: String, CaseIterable, AnalyticsPropertyConvertible {
    case quickPickPoolSize = "quick_pick_pool_size"
    case quickPickAge = "quick_pick_age"
    case quickPickApy = "quick_pick_apy"
    case quickPickRoot = "quick_pick_root"
    case pickerRootRow = "picker_root_row"
    case pickerSubnet = "picker_subnet"
    case subnetDetails = "subnet_details"
}

public enum StakingValidatorSource: String, CaseIterable, AnalyticsPropertyConvertible {
    case recommended
    case existingHotkey = "existing_hotkey"
    case manual
}

public enum StakingFailureStage: String, CaseIterable, AnalyticsPropertyConvertible {
    case notSubmitted = "not_submitted"
    case dispatched
}

public enum StakingCompletionOutcome: String, CaseIterable, AnalyticsPropertyConvertible {
    case done
    case unconfirmed
}

public enum StakingFlow: String, CaseIterable, AnalyticsPropertyConvertible {
    case stake
    case unstake
    case claim
}

public enum StakingBlockedReason: String, CaseIterable, AnalyticsPropertyConvertible {
    case ledger
    case proxy
    case multisigUnsupported = "multisig_unsupported"
    case watchOnly = "watch_only"
    case noAccount = "no_account"
    case noBalance = "no_balance"
    case tradesUnavailable = "trades_unavailable"
    case rootHold = "root_hold"
    case allLocked = "all_locked"
    case claimBelowMinimum = "claim_below_minimum"
    case claimPending = "claim_pending"
}

public enum AnalyticsWalletType: String, CaseIterable, AnalyticsPropertyConvertible {
    case secrets
    case watchOnly = "watch_only"
    case paritySigner = "parity_signer"
    case ledger
    case polkadotVault = "polkadot_vault"
    case proxied
    case genericLedger = "generic_ledger"
    case multisig
}

public enum StakingValidationKind: String, CaseIterable, AnalyticsPropertyConvertible {
    case minStake = "min_stake"
    case insufficientBalance = "insufficient_balance"
    case feeReserve = "fee_reserve"
    case priceImpact = "price_impact"
    case orderTooLarge = "order_too_large"
    case rateUpdated = "rate_updated"
    case priceMoved = "price_moved"
    case staleData = "stale_data"
    case dustRemainder = "dust_remainder"
    case holdLocked = "hold_locked"
    case feeInProgress = "fee_in_progress"
    case liquidity
}

public enum StakingValidationStage: String, CaseIterable, AnalyticsPropertyConvertible {
    case setup
    case confirm
}

public enum StakingValidationOutcome: String, CaseIterable, AnalyticsPropertyConvertible {
    case proceeded
    case cancelled
    case blocked
}

public enum SlippageChangeMethod: String, CaseIterable, AnalyticsPropertyConvertible {
    case preset
    case custom
    case reset
}

public enum SlippageWarning: String, CaseIterable, AnalyticsPropertyConvertible {
    case none
    case mayRevert = "may_revert"
    case mayFrontrun = "may_frontrun"
}

public enum SubnetListSource: String, CaseIterable, AnalyticsPropertyConvertible {
    case seeAllOptions = "see_all_options"
    case seeAllSubnets = "see_all_subnets"
    case setupCard = "setup_card"
}

public enum SubnetSortKey: String, CaseIterable, AnalyticsPropertyConvertible {
    case poolSize = "pool_size"
    case age
    case apy
    case sevenDayChange = "seven_day_change"
    case name
}

public enum SubnetListAction: String, CaseIterable, AnalyticsPropertyConvertible {
    case search
    case sort
    case filterThinPools = "filter_thin_pools"
    case favoriteAdded = "favorite_added"
    case favoriteRemoved = "favorite_removed"
}

public enum SubnetDetailsSource: String, CaseIterable, AnalyticsPropertyConvertible {
    case picker
    case setup
    case position
}

public enum AnalyticsPricePeriod: String, CaseIterable, AnalyticsPropertyConvertible {
    case day
    case week
    case month
    case quarter
    case year
    case all
}

public enum ValidatorChangeSource: String, CaseIterable, AnalyticsPropertyConvertible {
    case list
    case search
}

public enum StakingPortfolioSource: String, CaseIterable, AnalyticsPropertyConvertible {
    case dashboard
    case result
    case walletBalance = "wallet_balance"
}

public enum StakingChartState: String, CaseIterable, AnalyticsPropertyConvertible {
    case shown = "ok"
    case unavailable
}

public enum StakingRewardsState: String, CaseIterable, AnalyticsPropertyConvertible {
    case claimable
    case belowMinimum = "below_minimum"
    case none
    case unavailable
}

public enum StakingResultAction: String, CaseIterable, AnalyticsPropertyConvertible {
    case discoverSubnets = "discover_subnets"
    case viewPosition = "view_position"
    case yourBittensor = "your_bittensor"
    case backToPosition = "back_to_position"
    case tryAgain = "try_again"
    case close
}

public enum BittensorDataEndpoint: String, CaseIterable, AnalyticsPropertyConvertible {
    case subnets
    case validators
    case recommendations
    case portfolioHistory = "portfolio_history"
    case operations
    case rootOverview = "root_overview"
    case claimPreviews = "claim_previews"
    case priceServer = "price_server"
    case coingecko
    case chainRpc = "chain_rpc"
    case novaUtilsConfig = "nova_utils_config"
}

public enum BittensorDataFailureReason: String, CaseIterable, AnalyticsPropertyConvertible {
    case serverError = "server_error"
    case rateLimited = "rate_limited"
    case rejected
    case transport
    case contractViolation = "contract_violation"
    case generationStale = "generation_stale"
    case staleRates = "stale_rates"
}

public enum BittensorScreen: String, CaseIterable, AnalyticsPropertyConvertible {
    case landing
    case whereToStake = "where_to_stake"
    case subnetSelect = "subnet_select"
    case subnetDetails = "subnet_details"
    case validatorSelect = "validator_select"
    case setup
    case unstakeSetup = "unstake_setup"
    case confirm
    case claim
    case result
    case portfolio
    case position
}
