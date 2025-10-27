import Foundation
import os

protocol ApplicationConfigProtocol {
    var termsURL: URL { get }
    var privacyPolicyURL: URL { get }
    var supportEmail: String { get }
    var websiteURL: URL { get }
    var appStoreURL: URL { get }
    var externalUniversalLinkURL: URL { get }
    var internalUniversalLinkURL: URL { get }
    var deepLinkScheme: String { get }
    var deepLinkHost: String { get }
    var socialURL: URL { get }
    var version: String { get }
    var opensourceURL: URL { get }
    var twitterURL: URL { get }
    var youtubeURL: URL { get }
    var appName: String { get }
    var logoURL: URL { get }
    var purchaseAppName: String { get }
    var moonPayApiKey: String { get }
    var purchaseRedirect: URL { get }
    var phishingListURL: URL { get }
    var phishingDAppsURL: URL { get }
    var chainListURL: URL { get }
    var xcmDynamicTransfersURL: URL { get }
    var xcmTransfersURL: URL { get }
    var globalConfigURL: URL { get }
    var dAppsListURL: URL { get }
    var preferredValidatorsURL: URL { get }
    var governanceDAppsListURL: URL { get }
    var commonTypesURL: URL { get }
    var learnPayoutURL: URL { get }
    var learnControllerAccountURL: URL { get }
    var learnRecommendedValidatorsURL: URL { get }
    var paritySignerTroubleshoutingURL: URL { get }
    var polkadotVaultTroubleshoutingURL: URL { get }
    var controllerDeprecationURL: URL { get }
    var ledgerGuideURL: URL { get }
    var ledgerMigrationURL: URL { get }
    var canDebugDApp: Bool { get }
    var fileCachePath: String { get }
    var learnGovernanceDelegateMetadata: URL { get }
    var proxyWikiURL: URL { get }
    var multisigWikiURL: URL { get }
    var unifiedAddressWikiURL: URL { get }
    var inAppUpdatesEntrypointURL: URL { get }
    var inAppUpdatesChangelogsURL: URL { get }
    var slip44URL: URL { get }
    var wikiURL: URL { get }
    var whiteAppearanceIconsPath: String { get }
    var coloredAppearanceIconsPath: String { get }
}

extension ApplicationConfigProtocol {
    var deepLinkURL: URL {
        URL(string: "\(deepLinkScheme)://\(deepLinkHost)")!
    }
}

final class ApplicationConfig {
    static let shared = ApplicationConfig()
}

extension ApplicationConfig: ApplicationConfigProtocol {
    var termsURL: URL {
        URL(string: "https://novawallet.io/terms")!
    }

    var privacyPolicyURL: URL {
        URL(string: "https://novawallet.io/privacy")!
    }

    var supportEmail: String {
        "support@novawallet.io"
    }

    var websiteURL: URL {
        URL(string: "https://novawallet.io")!
    }

    var appStoreURL: URL {
        URL(string: "itms-apps://apple.com/app/id1597119355")!
    }

    var socialURL: URL {
        URL(string: "https://t.me/novawallet")!
    }

    var twitterURL: URL {
        URL(string: "https://twitter.com/NovaWalletApp")!
    }

    var youtubeURL: URL {
        URL(string: "https://www.youtube.com/channel/UChoQr3YPETJKKVvhQ0AfV6A")!
    }

    // swiftlint:disable force_cast
    var version: String {
        let bundle = Bundle(for: ApplicationConfig.self)

        let mainVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as! String
        let buildNumber = bundle.infoDictionary?["CFBundleVersion"] as! String

        return "\(mainVersion).\(buildNumber)"
    }

    // swiftlint:enable force_cast

    var opensourceURL: URL {
        URL(string: "https://github.com/novasamatech")!
    }

    // swiftlint:disable force_cast
    var appName: String {
        let bundle = Bundle(for: ApplicationConfig.self)
        return bundle.infoDictionary?["CFBundleDisplayName"] as! String
    }

    // swiftlint:enable force_cast

    var logoURL: URL {
        // swiftlint:disable:next line_length
        let logoString = "https://raw.githubusercontent.com/novasamatech/branding/master/logos/Nova_Wallet_Horizontal_iOS_Ramp.png"
        return URL(string: logoString)!
    }

    var purchaseAppName: String {
        "Nova Wallet"
    }

    var moonPayApiKey: String {
        "pk_live_Boi6Rl107p7XuJWBL8GJRzGWlmUSoxbz"
    }

    var purchaseRedirect: URL {
        URL(string: "novawallet://novawallet.io/redirect")!
    }

    var phishingListURL: URL {
        URL(string: "https://polkadot.js.org/phishing/address.json")!
    }

    var phishingDAppsURL: URL {
        URL(string: "https://polkadot.js.org/phishing/all.json")!
    }

    var phishingDAppsTopLevelSet: Set<String> {
        ["top"]
    }

    var chainListURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/v22/chains.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/v22/chains_dev.json")!
        #endif
    }

    var preConfiguredLightChainListURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/v22/preConfigured/chains.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/v22/preConfigured/chains_dev.json")!
        #endif
    }

    var preConfiguredChainDirectoryURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/v22/preConfigured/details")!
        #else
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/v22/preConfigured/detailsDev")!
        #endif
    }

    var evmAssetsURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/assets/evm/v3/assets.json")!
        #else
            URL(
                string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/assets/evm/v3/assets_dev.json"
            )!
        #endif
    }

    var xcmTransfersURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/xcm/v8/transfers.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/xcm/v8/transfers_dev.json")!
        #endif
    }

    var xcmDynamicTransfersURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/xcm/v8/transfers_dynamic.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/xcm/v8/transfers_dynamic_dev.json")!
        #endif
    }

    var globalConfigURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/global/config.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/global/config_dev.json")!
        #endif
    }

    var dAppsListURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/dapps/dapps.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/dapps/dapps_dev.json")!
        #endif
    }

    var preferredValidatorsURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/staking/validators/v1/nova_validators.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/staking/validators/v1/nova_validators_dev.json")!
        #endif
    }

    var governanceDAppsListURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/governance/v2/dapps.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/governance/v2/dapps_dev.json")!
        #endif
    }

    var canDebugDApp: Bool {
        #if F_RELEASE
            false
        #else
            true
        #endif
    }

    var fileCachePath: String {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("files-cache").path
    }

    var webPageRenderCachePath: String {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("webpage-renders-cache").path
    }

    var commonTypesURL: URL {
        URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/chains/types/default.json")!
    }

    var learnPayoutURL: URL {
        // swiftlint:disable:next line_length
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/staking/staking-faq#q-what-is-the-difference-between-restake-rewards-and-transferable-rewards")!
    }

    var learnControllerAccountURL: URL {
        // swiftlint:disable:next line_length
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/staking/staking-faq#q-what-are-stash-and-controller-accounts")!
    }

    var paritySignerTroubleshoutingURL: URL {
        // swiftlint:disable:next line_length
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/wallet-management/hardware-wallets/parity-signer/troubleshooting")!
    }

    var polkadotVaultTroubleshoutingURL: URL {
        // swiftlint:disable:next line_length
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/wallet-management/hardware-wallets/polkadot-vault/troubleshooting")!
    }

    var ledgerGuideURL: URL {
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/wallet-management/hardware-wallets/ledger-devices")!
    }

    var ledgerMigrationURL: URL {
        // swiftlint:disable:next line_length
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/wallet-management/hardware-wallets/ledger-nano-x/ledger-app-migration")!
    }

    var learnRecommendedValidatorsURL: URL {
        // swiftlint:disable:next line_length
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/staking/staking-faq#q-how-does-nova-wallet-select-validators-collators")!
    }

    var controllerDeprecationURL: URL {
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/staking/controller-account-deprecation")!
    }

    var learnGovernanceDelegateMetadata: URL {
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/governance/add-delegate-information")!
    }

    var learnNetworkManagementURL: URL {
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/misc/developer-documentation/integrate-network")!
    }

    // swiftlint:disable line_length
    var inAppUpdatesEntrypointURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-wallet-ios-releases/master/updates/v1/entrypoint_release.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-wallet-ios-releases/master/updates/v1/entrypoint_dev.json")!
        #endif
    }

    var inAppUpdatesChangelogsURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-wallet-ios-releases/master/updates/changelogs/release")!
        #else
            URL(string: "https://raw.githubusercontent.com/novasamatech/nova-wallet-ios-releases/master/updates/changelogs/dev")!
        #endif
    }

    var slip44URL: URL {
        URL(string: "https://raw.githubusercontent.com/novasamatech/nova-utils/master/assets/slip44.json")!
    }

    var wikiURL: URL {
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki")!
    }

    var proxyWikiURL: URL {
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/wallet-management/delegated-authorities-proxies")!
    }

    var multisigWikiURL: URL {
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/wallet-management/multisig-wallets")!
    }

    var unifiedAddressWikiURL: URL {
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/asset-management/how-to-receive-tokens#unified-and-legacy-addresses")!
    }

    var giftsWikiURL: URL {
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki")!
    }

    var externalUniversalLinkURL: URL {
        URL(string: "https://nova-wallet.app.link")!
    }

    var internalUniversalLinkURL: URL {
        #if F_RELEASE
            URL(string: "https://app.novawallet.io")!
        #else
            URL(string: "https://dev.novawallet.io")!
        #endif
    }

    var deepLinkScheme: String {
        "novawallet"
    }

    var deepLinkHost: String {
        "nova"
    }

    var whiteAppearanceIconsPath: String {
        "https://raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/icons/tokens/white/v1/"
    }

    var coloredAppearanceIconsPath: String {
        "https://raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/icons/tokens/colored/"
    }

    var bannersContentPath: String {
        "https://raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/banners/v2/content/"
    }

    var assetHubMigrationConfigsPath: String {
        "https://raw.githubusercontent.com/novasamatech/nova-utils/refs/heads/master/migrations/asset_hub/"
    }

    // swiftlint:enable line_length
}
