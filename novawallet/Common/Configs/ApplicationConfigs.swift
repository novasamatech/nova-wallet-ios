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
    var appName: String { get }
    var logoURL: URL { get }
    var purchaseAppName: String { get }
    var moonPayApiKey: String { get }
    var purchaseRedirect: URL { get }
    var phishingListURL: URL { get }
    var chainListURL: URL { get }
    var commonTypesURL: URL { get }
    var learnPayoutURL: URL { get }
    var learnControllerAccountURL: URL { get }
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
        URL(string: "https://apps.apple.com/us/app/nova-wallet-polkadot-kusama/id1591993285")!
    }

    var socialURL: URL {
        URL(string: "https://t.me/novawallet")!
    }

    var twitterURL: URL {
        URL(string: "https://twitter.com/NovaWalletApp")!
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

    var logoURL: URL { // FIXME: change to Nova repo
        // swiftlint:disable:next line_length
        let logoString = "https://raw.githubusercontent.com/sora-xor/sora-branding/master/Fearless-Wallet-brand/fearless-wallet-logo-ramp.png"
        return URL(string: logoString)!
    }

    var purchaseAppName: String {
        "Nova Wallet"
    }

    var moonPayApiKey: String {
        "pk_live_Boi6Rl107p7XuJWBL8GJRzGWlmUSoxbz"
    }

    var purchaseRedirect: URL { // FIXME: change to Nova address
        URL(string: "fearless://fearless.io/redirect")!
    }

    var phishingListURL: URL {
        URL(string: "https://polkadot.js.org/phishing/address.json")!
    }

    var chainListURL: URL {
        #if F_RELEASE
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/chains/v2/chains.json")!
        #else
            URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/chains/v2/chains_dev.json")!
        #endif
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
}
