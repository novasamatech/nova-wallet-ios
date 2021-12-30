import Foundation
@testable import novawallet

final class DAppListGenerator {
    static func createAnyDAppList() -> DAppList {
        DAppList(
            categories: [
                DAppCategory(identifier: "nft", name: "NFT"),
                DAppCategory(identifier: "staking", name: "Staking")
            ],
            dApps: [
                DApp(
                    name: "Polkadot JS",
                    url: URL(string: "https://polkadot.js/apps")!,
                    icon: nil,
                    categories: ["staking"]
                )
            ]
        )
    }
}
