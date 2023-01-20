import UIKit

final class AddDelegationInteractor {
    weak var presenter: AddDelegationInteractorOutputProtocol!
    let chain: ChainModel

    init(chain: ChainModel) {
        self.chain = chain
    }

    private func loadDelegates() {
        guard let precision = chain.utilityAsset()?.precision else {
            return
        }

        let nova = GovernanceDelegateLocal(
            stats: .init(
                address: "1",
                delegationsCount: 1311,
                delegatedVotes: Decimal(164_574.77).toSubstrateAmount(precision: Int16(precision)) ?? 0,
                recentVotes: 49
            ), metadata: .init(
                address: "1",
                name: "Novasama Technologies",
                image: URL(string: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/icons/chains/white/Polkadot.svg")!,
                shortDescription: "Company behind Nova Wallet",
                longDescription: nil,
                isOrganization: true
            )
        )
        let day7 = GovernanceDelegateLocal(
            stats: .init(
                address: "2",
                delegationsCount: 300,
                delegatedVotes: Decimal(10000).toSubstrateAmount(precision: Int16(precision)) ?? 0,
                recentVotes: 93
            ), metadata: .init(
                address: "2",
                name: "✨👍✨ Day7 ✨👍✨",
                image: URL(string: "https://static.tildacdn.com/tild3433-3038-4833-b464-396332313061/Frame_159.png")!,
                shortDescription: "CEO @ Novasama Technologies & Nova Foundation",
                longDescription: nil,
                isOrganization: false
            )
        )
        let gwood = GovernanceDelegateLocal(
            stats: .init(
                address: "3",
                delegationsCount: 299,
                delegatedVotes: Decimal(10000).toSubstrateAmount(precision: Int16(precision)) ?? 0,
                recentVotes: 13
            ), metadata: .init(
                address: "3",
                name: "Gavin Wood",
                image: URL(string: "https://static.tildacdn.com/tild3433-3038-4833-b464-396332313061/Frame_159.png")!,
                shortDescription: "Founded Polkadot, Kusama, Ethereum, Parity, Web3 Foundation. Building Polkadot. All things Web 3.0",
                longDescription: nil,
                isOrganization: false
            )
        )

        let delegates = [nova, day7, gwood]
        presenter.didReceiveDelegates(changes: delegates.map { .insert(newItem: $0) })
    }
}

extension AddDelegationInteractor: AddDelegationInteractorInputProtocol {
    func setup() {
        presenter.didReceive(chain: chain)
        loadDelegates()
    }
}
