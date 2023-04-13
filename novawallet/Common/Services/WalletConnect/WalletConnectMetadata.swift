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
            description: "Non-custodial Polkadot & Kusama wallet",
            website: "https://novawallet.io",
            icon: "https://github.com/nova-wallet/branding/raw/master/logos/Nova_Wallet_Horizontal_On_White_200px.png"
        )
    }
}
