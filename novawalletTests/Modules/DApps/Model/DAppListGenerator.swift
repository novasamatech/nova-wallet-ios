import Foundation
@testable import novawallet

final class DAppListGenerator {
    static func createAnyDAppList() -> DAppList {
        DAppList(
            popular: [
                DAppPopular(
                    url: URL(string: "https://polkadot.js/apps")!
                )
            ],
            categories: [
                DAppCategory(
                    identifier: "nft",
                    icon: nil,
                    name: "NFT"
                ),
                DAppCategory(
                    identifier: "staking",
                    icon: nil,
                    name: "Staking"
                )
            ],
            dApps: [
                DApp(
                    name: "Polkadot JS",
                    url: URL(string: "https://polkadot.js/apps")!,
                    icon: nil,
                    categories: ["staking"],
                    desktopOnly: nil
                )
            ]
        )
    }
}
