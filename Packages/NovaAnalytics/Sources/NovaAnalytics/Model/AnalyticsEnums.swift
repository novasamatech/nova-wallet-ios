import Foundation

public enum AssetCategory: String, AnalyticsPropertyConvertible {
    case nativeToken = "native_token"
    case stablecoin
    case wrappedToken = "wrapped_token"
    case other
}

public enum WalletCreationMethod: String, AnalyticsPropertyConvertible {
    case create
    case importMnemonic = "import_mnemonic"
    case importSeed = "import_seed"
    case importJson = "import_json"
    case importLedger = "import_ledger"
    case importParitySigner = "import_parity_signer"
    case importPolkadotVault = "import_polkadot_vault"
    case importWatchOnly = "import_watch_only"
    case cloudBackup = "cloud_backup"
}

public enum SwapSource: String, AnalyticsPropertyConvertible {
    case assetDetails = "asset_details"
    case mainScreen = "main_screen"
    case operationDetails = "operation_details"
    case retry
}

public enum SwapFailureReason: String, AnalyticsPropertyConvertible {
    case networkError = "network_error"
    case executionReverted = "execution_reverted"
    case userCancelled = "user_cancelled"
    case unknown
}

public enum StakingStage: String, AnalyticsPropertyConvertible {
    case landing
    case setup
    case typeSelection = "type_selection"
    case confirm
}

public enum SwapStage: String, AnalyticsPropertyConvertible {
    case setup
    case confirm
}

public enum FeatureId: String, AnalyticsPropertyConvertible {
    case staking
    case governance
    case crowdloans
    case dapps
    case nft
    case swap
    case buy
    case send
    case receive
    case settings
}

public enum OnboardingSource: String, AnalyticsPropertyConvertible {
    case freshInstall = "fresh_install"
    case addWallet = "add_wallet"
}

public enum WalletCreationStep: String, AnalyticsPropertyConvertible {
    case welcome
    case backup
    case confirmMnemonic = "confirm_mnemonic"
    case pinSetup = "pin_setup"
    case seedEntry = "seed_entry"
    case jsonUpload = "json_upload"
    case ledgerConnect = "ledger_connect"
    case other
}

public enum SignSource: String, AnalyticsPropertyConvertible {
    case dappBrowser = "dapp_browser"
    case walletConnect = "walletconnect"
}

public enum AnalyticsTab: String, AnalyticsPropertyConvertible {
    case assets
    case vote
    case dapps
    case staking
    case settings
}

public enum StakingAnalyticsType: String, AnalyticsPropertyConvertible {
    case direct
    case pool
    case mythos
    case unsupported
}

public enum TransactionFailureReason: String, AnalyticsPropertyConvertible {
    case userCancelled = "user_cancelled"
    case networkError = "network_error"
    case unknown
}

public enum SignFailureReason: String, AnalyticsPropertyConvertible {
    case signingFailed = "signing_failed"
    case noSession = "no_session"
    case unsupportedRequest = "unsupported_request"
}

public enum DAppOpenSource: String, AnalyticsPropertyConvertible {
    case catalog
    case favorites
    case search
    case manualUrl = "manual_url"
}

public enum VoteDirection: String, AnalyticsPropertyConvertible {
    case aye
    case nay
    case abstain
}

public enum ConvictionLevel: String, AnalyticsPropertyConvertible {
    case noLockup = "0.1x"
    case locked1x = "1x"
    case locked2x = "2x"
    case locked3x = "3x"
    case locked4x = "4x"
    case locked5x = "5x"
    case locked6x = "6x"
}

public enum StakingFlowSource: String, AnalyticsPropertyConvertible {
    case dashboard
    case assetDetails = "asset_details"
}

public enum AnalyticsBannerScreen: String, AnalyticsPropertyConvertible {
    case dApps = "dapps"
    case assets
    case ahmKusama = "ahm_kusama"
    case ahmPolkadot = "ahm_polkadot"
    case unknown
}
