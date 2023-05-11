import Foundation

struct WalletConnectMetadata {
    let projectId: String
    let name: String
    let description: String
    let website: String
    let icon: String
}

extension WalletConnectMetadata {
    static func nova(with projectId: String) -> WalletConnectMetadata {
        .init(
            projectId: projectId,
            name: "Nova wallet",
            description: "Next-gen wallet for Polkadot and Kusama ecosystem",
            website: "https://novawallet.io",
            icon: "https://raw.githubusercontent.com/nova-wallet/branding/master/logos/Nova_Wallet_Star_Color.png"
        )
    }
}
