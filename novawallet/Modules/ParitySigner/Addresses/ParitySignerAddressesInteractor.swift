import UIKit
import RobinHood

final class ParitySignerAddressesInteractor {
    weak var presenter: ParitySignerAddressesInteractorOutputProtocol?

    let addressScan: ParitySignerAddressScan
    let chainRegistry: ChainRegistryProtocol

    init(
        addressScan: ParitySignerAddressScan,
        chainRegistry: ChainRegistryProtocol
    ) {
        self.addressScan = addressScan
        self.chainRegistry = chainRegistry
    }

    private func provideAccountId(from addressScan: ParitySignerAddressScan, chain: ChainModel) {
        do {
            let accountId = try addressScan.address.toAccountId(using: chain.chainFormat)
            presenter?.didReceive(accountId: accountId)
        } catch {
            presenter?.didReceive(error: error)
        }
    }

    private func matchChain(
        for addressScan: ParitySignerAddressScan,
        from changes: [DataProviderChange<ChainModel>]
    ) -> ChainModel? {
        for change in changes {
            switch change {
            case let .insert(newItem), let .update(newItem):
                let genesisHash = try? Data(hexString: newItem.chainId)

                if genesisHash == addressScan.genesisHash {
                    return newItem
                }
            case .delete:
                break
            }
        }

        return nil
    }

    private func subscribeChainsProvidingAccountId(from addressScan: ParitySignerAddressScan) {
        chainRegistry.chainsSubscribe(self, runningInQueue: .main) { [weak self] changes in
            if let addressChain = self?.matchChain(for: addressScan, from: changes) {
                self?.provideAccountId(from: addressScan, chain: addressChain)
            }

            self?.presenter?.didReceive(chains: changes)
        }
    }
}

extension ParitySignerAddressesInteractor: ParitySignerAddressesInteractorInputProtocol {
    func setup() {
        subscribeChainsProvidingAccountId(from: addressScan)
    }
}
