import UIKit
import Operation_iOS

final class PVAddressesInteractor {
    weak var presenter: PVAddressesInteractorOutputProtocol?

    let account: PolkadotVaultAccount
    let chainRegistry: ChainRegistryProtocol

    init(
        account: PolkadotVaultAccount,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.account = account
        self.chainRegistry = chainRegistry
    }
}

// MARK: - Private

private extension PVAddressesInteractor {
    func provideAccountId(
        from accountScan: PolkadotVaultAccount,
        chain: ChainModel
    ) {
        do {
            let accountId = try accountScan.address.toAccountId(using: chain.chainFormat)
            presenter?.didReceive(accountId: accountId)
        } catch {
            presenter?.didReceive(error: error)
        }
    }

    func matchChain(
        for accountScan: PolkadotVaultAccount,
        from changes: [DataProviderChange<ChainModel>]
    ) -> ChainModel? {
        for change in changes {
            switch change {
            case let .insert(newItem), let .update(newItem):
                let genesisHash = try? Data(hexString: newItem.chainId)

                if genesisHash == accountScan.genesisHash {
                    return newItem
                }
            case .delete:
                break
            }
        }

        return nil
    }

    func subscribeChainsProvidingAccountId(from accountScan: PolkadotVaultAccount) {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            if let addressChain = self?.matchChain(for: accountScan, from: changes) {
                self?.provideAccountId(from: accountScan, chain: addressChain)
            }

            self?.presenter?.didReceive(chains: changes)
        }
    }
}

// MARK: - PVAddressesInteractorInputProtocol

extension PVAddressesInteractor: PVAddressesInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(account: account)
        subscribeChainsProvidingAccountId(from: account)
    }
}
