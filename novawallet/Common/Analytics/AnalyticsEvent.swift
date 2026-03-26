import Foundation

enum AnalyticsEvent {
    // App lifecycle
    case appOpened(isFirstLaunch: Bool)
    case sessionStarted
    case sessionEnded(durationBucket: DurationBucket)

    // Onboarding
    case onboardingStarted(source: OnboardingSource)
    case walletCreationMethodSelected(method: WalletCreationMethod)
    case walletCreationStarted(method: WalletCreationMethod)
    case walletCreationCompleted(method: WalletCreationMethod, durationBucket: DurationBucket? = nil)
    case walletCreationAbandoned(lastStep: WalletCreationStep)
    case firstActionAfterWallet(action: FirstAction)

    // Features
    case featureOpened(featureId: FeatureId)

    // Swap
    case swapScreenOpened(source: SwapSource)
    case swapInitiated(
        source: SwapSource,
        assetInCategory: AssetCategory,
        assetOutCategory: AssetCategory,
        assetIn: String,
        assetOut: String,
        networkIn: String,
        networkOut: String,
        amountBucket: AmountBucket
    )
    case swapConfirmed(
        amountBucket: AmountBucket,
        slippageBucket: SlippageBucket,
        assetIn: String,
        assetOut: String,
        networkIn: String,
        networkOut: String
    )
    case swapCompleted(
        amountBucket: AmountBucket,
        durationBucket: DurationBucket,
        assetIn: String,
        assetOut: String,
        networkIn: String,
        networkOut: String
    )
    case swapFailed(reason: SwapFailureReason)
    case swapAbandoned(stage: SwapStage)

    // Staking
    case stakingFlowOpened(network: String, source: String)
    case stakingTypeSelected(stakingType: String, network: String)
    case stakingInitiated(stakingType: String, network: String, amountBucket: AmountBucket)
    case stakingConfirmed(stakingType: String, network: String, amountBucket: AmountBucket)
    case stakingCompleted(stakingType: String, network: String, amountBucket: AmountBucket)
    case stakingFailed(stakingType: String, network: String, reason: String)
    case unstakeInitiated(stakingType: String, network: String, amountBucket: AmountBucket)
    case unstakeCompleted(stakingType: String, network: String, amountBucket: AmountBucket)
    case unstakeFailed(stakingType: String, network: String, reason: String)

    // Transfers
    case sendInitiated(asset: String, network: String, destinationNetwork: String?, assetCategory: AssetCategory, amountBucket: AmountBucket, isCrossChain: Bool)
    case sendCompleted(asset: String, network: String, amountBucket: AmountBucket, destinationNetwork: String? = nil)
    case sendFailed(asset: String, network: String, reason: String, destinationNetwork: String? = nil)

    // DApp
    case dappOpened(dappHost: String, source: String, isKnownDapp: Bool)

    // Banners
    case bannerClicked(bannerId: String, bannerTitle: String, screen: String)

    // Nova Card
    case novaCardOpened

    // NFT
    case nftSectionOpened(nftCount: Int)

    // Governance
    case governanceVoteCast(voteDirection: String, network: String, amountBucket: AmountBucket, convictionLevel: String)

    // General
    case tabSwitched(tab: String)
    case buyInitiated(provider: String, asset: String, network: String)

    var name: String {
        switch self {
        case .appOpened: return "app_opened"
        case .sessionStarted: return "session_started"
        case .sessionEnded: return "session_ended"
        case .onboardingStarted: return "onboarding_started"
        case .walletCreationMethodSelected: return "wallet_creation_method_selected"
        case .walletCreationStarted: return "wallet_creation_started"
        case .walletCreationCompleted: return "wallet_creation_completed"
        case .walletCreationAbandoned: return "wallet_creation_abandoned"
        case .firstActionAfterWallet: return "first_action_after_wallet"
        case .featureOpened: return "feature_opened"
        case .swapScreenOpened: return "swap_screen_opened"
        case .swapInitiated: return "swap_initiated"
        case .swapConfirmed: return "swap_confirmed"
        case .swapCompleted: return "swap_completed"
        case .swapFailed: return "swap_failed"
        case .swapAbandoned: return "swap_abandoned"
        case .stakingFlowOpened: return "staking_flow_opened"
        case .stakingTypeSelected: return "staking_type_selected"
        case .stakingInitiated: return "staking_initiated"
        case .stakingConfirmed: return "staking_confirmed"
        case .stakingCompleted: return "staking_completed"
        case .stakingFailed: return "staking_failed"
        case .unstakeInitiated: return "unstake_initiated"
        case .unstakeCompleted: return "unstake_completed"
        case .unstakeFailed: return "unstake_failed"
        case .sendInitiated: return "send_initiated"
        case .sendCompleted: return "send_completed"
        case .sendFailed: return "send_failed"
        case .dappOpened: return "dapp_opened"
        case .bannerClicked: return "banner_clicked"
        case .novaCardOpened: return "nova_card_opened"
        case .nftSectionOpened: return "nft_section_opened"
        case .governanceVoteCast: return "governance_vote_cast"
        case .tabSwitched: return "tab_switched"
        case .buyInitiated: return "buy_initiated"
        }
    }

    var properties: [String: Any] {
        switch self {
        case let .appOpened(isFirstLaunch):
            return [
                "is_first_launch": isFirstLaunch,
                "$ip": false
            ]
        case .sessionStarted:
            return [
                "$ip": false
            ]
        case let .sessionEnded(durationBucket):
            return [
                "duration_bucket": durationBucket.rawValue,
                "$ip": false
            ]
        case let .onboardingStarted(source):
            return [
                "source": source.rawValue,
                "$ip": false
            ]
        case let .walletCreationMethodSelected(method):
            return [
                "method": method.rawValue,
                "$ip": false
            ]
        case let .walletCreationStarted(method):
            return [
                "method": method.rawValue,
                "$ip": false
            ]
        case let .walletCreationCompleted(method, durationBucket):
            var props: [String: Any] = [
                "method": method.rawValue,
                "$ip": false
            ]
            if let durationBucket = durationBucket {
                props["duration_bucket"] = durationBucket.rawValue
            }
            return props
        case let .walletCreationAbandoned(lastStep):
            return [
                "last_step": lastStep.rawValue,
                "$ip": false
            ]
        case let .firstActionAfterWallet(action):
            return [
                "action": action.rawValue,
                "$ip": false
            ]
        case let .featureOpened(featureId):
            return [
                "feature_id": featureId.rawValue,
                "$ip": false
            ]
        case let .swapScreenOpened(source):
            return [
                "source": source.rawValue,
                "$ip": false
            ]
        case let .swapInitiated(source, assetInCategory, assetOutCategory, assetIn, assetOut, networkIn, networkOut, amountBucket):
            return [
                "source": source.rawValue,
                "asset_in_category": assetInCategory.rawValue,
                "asset_out_category": assetOutCategory.rawValue,
                "asset_in": assetIn,
                "asset_out": assetOut,
                "network_in": networkIn,
                "network_out": networkOut,
                "amount_bucket": amountBucket.rawValue,
                "$ip": false
            ]
        case let .swapConfirmed(amountBucket, slippageBucket, assetIn, assetOut, networkIn, networkOut):
            return [
                "amount_bucket": amountBucket.rawValue,
                "slippage_bucket": slippageBucket.rawValue,
                "asset_in": assetIn,
                "asset_out": assetOut,
                "network_in": networkIn,
                "network_out": networkOut,
                "$ip": false
            ]
        case let .swapCompleted(amountBucket, durationBucket, assetIn, assetOut, networkIn, networkOut):
            return [
                "amount_bucket": amountBucket.rawValue,
                "duration_bucket": durationBucket.rawValue,
                "asset_in": assetIn,
                "asset_out": assetOut,
                "network_in": networkIn,
                "network_out": networkOut,
                "$ip": false
            ]
        case let .swapFailed(reason):
            return [
                "reason": reason.rawValue,
                "$ip": false
            ]
        case let .swapAbandoned(stage):
            return [
                "stage": stage.rawValue,
                "$ip": false
            ]
        case let .stakingFlowOpened(network, source):
            return [
                "network": network,
                "source": source,
                "$ip": false
            ]
        case let .stakingTypeSelected(stakingType, network):
            return [
                "staking_type": stakingType,
                "network": network,
                "$ip": false
            ]
        case let .stakingInitiated(stakingType, network, amountBucket):
            return [
                "staking_type": stakingType,
                "network": network,
                "amount_bucket": amountBucket.rawValue,
                "$ip": false
            ]
        case let .stakingConfirmed(stakingType, network, amountBucket):
            return [
                "staking_type": stakingType,
                "network": network,
                "amount_bucket": amountBucket.rawValue,
                "$ip": false
            ]
        case let .stakingCompleted(stakingType, network, amountBucket):
            return [
                "staking_type": stakingType,
                "network": network,
                "amount_bucket": amountBucket.rawValue,
                "$ip": false
            ]
        case let .stakingFailed(stakingType, network, reason):
            return [
                "staking_type": stakingType,
                "network": network,
                "reason": reason,
                "$ip": false
            ]
        case let .unstakeInitiated(stakingType, network, amountBucket):
            return [
                "staking_type": stakingType,
                "network": network,
                "amount_bucket": amountBucket.rawValue,
                "$ip": false
            ]
        case let .unstakeCompleted(stakingType, network, amountBucket):
            return [
                "staking_type": stakingType,
                "network": network,
                "amount_bucket": amountBucket.rawValue,
                "$ip": false
            ]
        case let .unstakeFailed(stakingType, network, reason):
            return [
                "staking_type": stakingType,
                "network": network,
                "reason": reason,
                "$ip": false
            ]
        case let .sendInitiated(asset, network, destinationNetwork, assetCategory, amountBucket, isCrossChain):
            var props: [String: Any] = [
                "asset": asset,
                "network": network,
                "asset_category": assetCategory.rawValue,
                "amount_bucket": amountBucket.rawValue,
                "is_cross_chain": isCrossChain,
                "$ip": false
            ]
            if let destNetwork = destinationNetwork {
                props["destination_network"] = destNetwork
            }
            return props
        case let .sendCompleted(asset, network, amountBucket, destinationNetwork):
            var props: [String: Any] = [
                "asset": asset,
                "network": network,
                "amount_bucket": amountBucket.rawValue,
                "$ip": false
            ]
            if let destinationNetwork {
                props["destination_network"] = destinationNetwork
            }
            return props
        case let .sendFailed(asset, network, reason, destinationNetwork):
            var props: [String: Any] = [
                "asset": asset,
                "network": network,
                "reason": reason,
                "$ip": false
            ]
            if let destinationNetwork {
                props["destination_network"] = destinationNetwork
            }
            return props
        case let .dappOpened(dappHost, source, isKnownDapp):
            return [
                "dapp_host": dappHost,
                "source": source,
                "is_known_dapp": isKnownDapp,
                "$ip": false
            ]
        case let .bannerClicked(bannerId, bannerTitle, screen):
            return [
                "banner_id": bannerId,
                "banner_title": bannerTitle,
                "screen": screen,
                "$ip": false
            ]
        case .novaCardOpened:
            return [
                "$ip": false
            ]
        case let .nftSectionOpened(nftCount):
            return [
                "nft_count": nftCount,
                "$ip": false
            ]
        case let .governanceVoteCast(voteDirection, network, amountBucket, convictionLevel):
            return [
                "vote_direction": voteDirection,
                "network": network,
                "amount_bucket": amountBucket.rawValue,
                "conviction_level": convictionLevel,
                "$ip": false
            ]
        case let .tabSwitched(tab):
            return [
                "tab": tab,
                "$ip": false
            ]
        case let .buyInitiated(provider, asset, network):
            return [
                "provider": provider,
                "asset": asset,
                "network": network,
                "$ip": false
            ]
        }
    }
}

// MARK: - Supporting Enums

enum AssetCategory: String {
    case nativeToken = "native_token"
    case stablecoin
    case wrappedToken = "wrapped_token"
    case other

    private static let stablecoins: Set<String> = [
        "USDT", "USDC", "DAI", "BUSD", "TUSD", "FRAX", "LUSD",
        "USDP", "GUSD", "USDD", "CRVUSD", "GHO", "PYUSD",
        "AUSD", "IUSD"
    ]

    private static let wrappedTokens: Set<String> = [
        "WETH", "WBTC", "WBNB", "WAVAX", "WMATIC", "WFTM",
        "WGLMR", "WMOVR", "WDOT", "WKSM"
    ]

    static func classify(_ chainAsset: ChainAsset) -> AssetCategory {
        let symbol = chainAsset.asset.symbol.uppercased()

        if chainAsset.asset.isUtility { return .nativeToken }
        if stablecoins.contains(symbol) { return .stablecoin }
        if wrappedTokens.contains(symbol) { return .wrappedToken }
        if symbol.hasPrefix("W") { return .wrappedToken }
        return .other
    }
}

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
    case signingUnavailable = "signing_unavailable"
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

enum WalletCreationStep: String {
    case welcome
    case backup
    case confirmMnemonic = "confirm_mnemonic"
    case pinSetup = "pin_setup"
    case networkSelection = "network_selection"
    case seedEntry = "seed_entry"
    case jsonUpload = "json_upload"
    case ledgerConnect = "ledger_connect"
    case other
}
