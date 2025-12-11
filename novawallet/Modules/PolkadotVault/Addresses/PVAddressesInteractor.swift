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
