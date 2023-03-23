import Foundation
import os

protocol ApplicationConfigProtocol {
    var termsURL: URL { get }
    var privacyPolicyURL: URL { get }
    var supportEmail: String { get }
    var websiteURL: URL { get }
    var appStoreURL: URL { get }
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
    var xcmTransfersURL: URL { get }
    var dAppsListURL: URL { get }
    var governanceDAppsListURL: URL { get }
    var commonTypesURL: URL { get }
    var learnPayoutURL: URL { get }
    var learnControllerAccountURL: URL { get }
    var learnRecommendedValidatorsURL: URL { get }
    var paritySignerTroubleshoutingURL: URL { get }
    var ledgerGuideURL: URL { get }
    var canDebugDApp: Bool { get }
    var fileCachePath: String { get }
    var learnGovernanceDelegateMetadata: URL { get }
    var inAppUpdatesEntrypointURL: URL { get }
    var inAppUpdatesChangelogsURL: URL { get }
    var slip44URL: URL { get }
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
        URL(string: "https://github.com/nova-wallet")!
    }

    // swiftlint:disable force_cast
    var appName: String {
        let bundle = Bundle(for: ApplicationConfig.self)
        return bundle.infoDictionary?["CFBundleDisplayName"] as! String
    }

    // swiftlint:enable force_cast

    var logoURL: URL {
        // swiftlint:disable:next line_length
        let logoString = "https://raw.githubusercontent.com/nova-wallet/branding/master/logos/Nova_Wallet_Horizontal_iOS_Ramp.png"
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

    var chainListURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/chains/v8/chains.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/chains/v8/chains_dev.json")!
        #endif
    }

    var evmAssetsURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/assets/evm/v1/assets.json")!
        #else
            URL(
                string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/assets/evm/v1/assets_dev.json"
            )!
        #endif
    }

    var xcmTransfersURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/xcm/v2/transfers.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/xcm/v2/transfers_dev.json")!
        #endif
    }

    var dAppsListURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/dapps/dapps.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/dapps/dapps_dev.json")!
        #endif
    }

    var governanceDAppsListURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/governance/v2/dapps.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/governance/v2/dapps_dev.json")!
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

    var commonTypesURL: URL {
        URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/chains/types/default.json")!
    }

    var learnPayoutURL: URL {
        URL(string: "https://wiki.polkadot.network/docs/en/learn-simple-payouts")!
    }

    var learnControllerAccountURL: URL {
        // swiftlint:disable:next line_length
        URL(string: "https://wiki.polkadot.network/docs/en/maintain-guides-how-to-nominate-polkadot#setting-up-stash-and-controller-keys")!
    }

    var paritySignerTroubleshoutingURL: URL {
        URL(string: "https://github.com/nova-wallet/nova-utils/wiki/Parity-Signer-troubleshooting")!
    }

    var ledgerGuideURL: URL {
        URL(string: "https://support.ledger.com/hc/en-us/articles/360019138694-Set-up-Bluetooth-connection")!
    }

    var learnRecommendedValidatorsURL: URL {
        URL(string: "https://github.com/nova-wallet/nova-utils/wiki/Recommended-validators-in-Nova-Wallet")!
    }

    var learnGovernanceDelegateMetadata: URL {
        URL(string: "https://docs.novawallet.io/nova-wallet-wiki/governance/add-delegate-information")!
    }

    var inAppUpdatesEntrypointURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-wallet-ios-releases/master/updates/v1/entrypoint_release.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-wallet-ios-releases/master/updates/v1/entrypoint_dev.json")!
        #endif
    }

    var inAppUpdatesChangelogsURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-wallet-ios-releases/master/updates/changelogs/release")!
        #else
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-wallet-ios-releases/master/updates/changelogs/dev")!
        #endif
    }

    var slip44URL: URL {
        URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/assets/slip44.json")!
    }
}
