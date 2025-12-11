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
    func provideAccountId(from accountScan: PolkadotVaultAccount) {
        do {
            let accountId = try accountScan.address.toAccountId(using: .multichainDisplayFormat)
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

    func subscribeChainsProvidingAccountId() {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            self?.presenter?.didReceive(chains: changes)
        }
    }
}

// MARK: - PVAddressesInteractorInputProtocol

extension PVAddressesInteractor: PVAddressesInteractorInputProtocol {
    func setup() {
        presenter?.didReceive(account: account)
        provideAccountId(from: account)

        subscribeChainsProvidingAccountId()
    }
}
