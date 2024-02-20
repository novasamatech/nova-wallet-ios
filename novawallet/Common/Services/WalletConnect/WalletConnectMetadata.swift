import Foundation

struct WalletConnectMetadata {
    struct Redirect {
        let native: String?
        let universal: String?
    }

    let projectId: String
    let name: String
    let description: String
    let website: String
    let icon: String
    let redirect: Redirect
}

extension WalletConnectMetadata {
    static func nova(with projectId: String) -> WalletConnectMetadata {
        .init(
            projectId: projectId,
            name: "Nova wallet",
            description: "Next-gen wallet for Polkadot and Kusama ecosystem",
            website: "https://novawallet.io",
            icon: "https://raw.githubusercontent.com/novasamatech/branding/master/logos/Nova_Wallet_Star_Color.png",
            redirect: .init(
                native: "novawallet://request",
                universal: nil
            )
        )
    }
}
