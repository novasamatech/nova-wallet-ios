import Foundation

enum AnalyticsEvent {
    // App lifecycle
    case appOpened(isFirstLaunch: Bool)
    case sessionStarted
    case sessionEnded(durationBucket: DurationBucket)
    case featureOpened(featureId: FeatureId)

    // Onboarding
    case onboardingStarted(source: OnboardingSource)
    case walletCreationMethodSelected(method: WalletCreationMethod)
    case walletCreationStarted(method: WalletCreationMethod)
    case walletCreationCompleted(method: WalletCreationMethod, durationBucket: DurationBucket)
    case walletCreationAbandoned(lastStep: String)
    case firstActionAfterWallet(action: FirstAction)

    // Swap
    case swapScreenOpened(source: SwapSource)
    case swapInitiated(source: SwapSource, assetIn: String, assetOut: String, amountBucket: AmountBucket)
    case swapConfirmed(amountBucket: AmountBucket, slippageBucket: SlippageBucket)
    case swapCompleted(amountBucket: AmountBucket, durationBucket: DurationBucket)
    case swapFailed(reason: SwapFailureReason)
    case swapAbandoned(stage: SwapStage)

    var name: String {
        switch self {
        case .appOpened: return "app_opened"
        case .sessionStarted: return "session_started"
        case .sessionEnded: return "session_ended"
        case .featureOpened: return "feature_opened"
        case .onboardingStarted: return "onboarding_started"
        case .walletCreationMethodSelected: return "wallet_creation_method_selected"
        case .walletCreationStarted: return "wallet_creation_started"
        case .walletCreationCompleted: return "wallet_creation_completed"
        case .walletCreationAbandoned: return "wallet_creation_abandoned"
        case .firstActionAfterWallet: return "first_action_after_wallet"
        case .swapScreenOpened: return "swap_screen_opened"
        case .swapInitiated: return "swap_initiated"
        case .swapConfirmed: return "swap_confirmed"
        case .swapCompleted: return "swap_completed"
        case .swapFailed: return "swap_failed"
        case .swapAbandoned: return "swap_abandoned"
        }
    }

    var properties: [String: Any] {
        switch self {
        case let .appOpened(isFirstLaunch):
            return ["is_first_launch": isFirstLaunch]
        case .sessionStarted:
            return [:]
        case let .sessionEnded(durationBucket):
            return ["duration_bucket": durationBucket.rawValue]
        case let .featureOpened(featureId):
            return ["feature_id": featureId.rawValue]
        case let .onboardingStarted(source):
            return ["source": source.rawValue]
        case let .walletCreationMethodSelected(method):
            return ["method": method.rawValue]
        case let .walletCreationStarted(method):
            return ["method": method.rawValue]
        case let .walletCreationCompleted(method, durationBucket):
            return ["method": method.rawValue, "duration_bucket": durationBucket.rawValue]
        case let .walletCreationAbandoned(lastStep):
            return ["last_step": lastStep]
        case let .firstActionAfterWallet(action):
            return ["action": action.rawValue]
        case let .swapScreenOpened(source):
            return ["source": source.rawValue]
        case let .swapInitiated(source, assetIn, assetOut, amountBucket):
            var props: [String: Any] = ["source": source.rawValue, "amount_bucket": amountBucket.rawValue]
            if !assetIn.isEmpty { props["asset_in"] = assetIn }
            if !assetOut.isEmpty { props["asset_out"] = assetOut }
            return props
        case let .swapConfirmed(amountBucket, slippageBucket):
            return ["amount_bucket": amountBucket.rawValue, "slippage_bucket": slippageBucket.rawValue]
        case let .swapCompleted(amountBucket, durationBucket):
            return ["amount_bucket": amountBucket.rawValue, "duration_bucket": durationBucket.rawValue]
        case let .swapFailed(reason):
            return ["reason": reason.rawValue]
        case let .swapAbandoned(stage):
            return ["stage": stage.rawValue]
        }
    }
}

// MARK: - Supporting Enums

enum WalletCreationMethod: String {
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

enum SwapSource: String {
    case assetDetails = "asset_details"
    case mainScreen = "main_screen"
    case deepLink = "deep_link"
}

enum SwapFailureReason: String {
    case insufficientBalance = "insufficient_balance"
    case slippageExceeded = "slippage_exceeded"
    case networkError = "network_error"
    case executionReverted = "execution_reverted"
    case userCancelled = "user_cancelled"
    case unknown
}

enum SwapStage: String {
    case setup
    case confirm
    case executing
}

enum FeatureId: String {
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

enum OnboardingSource: String {
    case freshInstall = "fresh_install"
    case addWallet = "add_wallet"
}

enum FirstAction: String {
    case swap
    case send
    case receive
    case staking
    case dapp
    case buy
    case other
}

// MARK: - Factory Methods (defaults for convenience)

extension AnalyticsEvent {
    static func swapInitiatedDefault(source: SwapSource = .mainScreen) -> AnalyticsEvent {
        .swapInitiated(source: source, assetIn: "", assetOut: "", amountBucket: .under1)
    }

    static func swapConfirmedDefault() -> AnalyticsEvent {
        .swapConfirmed(amountBucket: .under1, slippageBucket: .low)
    }

    static func swapCompletedDefault() -> AnalyticsEvent {
        .swapCompleted(amountBucket: .under1, durationBucket: .under5s)
    }
}
