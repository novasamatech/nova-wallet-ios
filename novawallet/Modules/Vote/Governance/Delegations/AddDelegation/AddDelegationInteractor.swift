import UIKit

final class AddDelegationInteractor {
    weak var presenter: AddDelegationInteractorOutputProtocol!
    let chain: ChainModel

    init(chain: ChainModel) {
        self.chain = chain
    }

    private func loadDelegators() {
        guard let precision = chain.utilityAsset()?.precision else {
            return
        }

        let nova = DelegateMetadataLocal(
            accountId: Data.random(of: 32)!,
            name: "Novasama Technologies",
            address: "",
            shortDescription: "Company behind Nova Wallet",
            longDescription: nil,
            profileImageUrl: "https://raw.githubusercontent.com/nova-wallet/nova-utils/master/icons/chains/white/Polkadot.svg",
            isOrganization: true,
            stats: DelegateStatistic(
                delegations: 1311,
                delegatedVotesInPlank: Decimal(164_574.77).toSubstrateAmount(precision: Int16(precision)) ?? 0,
                recentVotes: 49
            )
        )
        let day7 = DelegateMetadataLocal(
            accountId: Data.random(of: 32)!,
            name: "✨👍✨ Day7 ✨👍✨",
            address: "",
            shortDescription: "CEO @ Novasama Technologies & Nova Foundation",
            longDescription: nil,
            profileImageUrl: "https://static.tildacdn.com/tild3433-3038-4833-b464-396332313061/Frame_159.png",
            isOrganization: false,
            stats: DelegateStatistic(
                delegations: 300,
                delegatedVotesInPlank: Decimal(10000).toSubstrateAmount(precision: Int16(precision)) ?? 0,
                recentVotes: 93
            )
        )

        let gwood = DelegateMetadataLocal(
            accountId: Data.random(of: 32)!,
            name: "Gavin Wood",
            address: "",
            shortDescription: "Founded Polkadot, Kusama, Ethereum, Parity, Web3 Foundation. Building Polkadot. All things Web 3.0",
            longDescription: nil,
            profileImageUrl: "https://static.tildacdn.com/tild3433-3038-4833-b464-396332313061/Frame_159.png",
            isOrganization: false,
            stats: DelegateStatistic(
                delegations: 299,
                delegatedVotesInPlank: Decimal(10000).toSubstrateAmount(precision: Int16(precision)) ?? 0,
                recentVotes: 13
            )
        )

        let delegators = [nova, day7, gwood]
        presenter.didReceive(delegatorsChanges: delegators.map { .insert(newItem: $0) })
    }
}

extension AddDelegationInteractor: AddDelegationInteractorInputProtocol {
    func setup() {
        presenter.didReceive(chain: chain)
        loadDelegators()
    }
}
