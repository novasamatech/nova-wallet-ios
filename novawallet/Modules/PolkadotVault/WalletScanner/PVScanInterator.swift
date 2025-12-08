import Foundation
import Operation_iOS

enum PVScanInteratorError: Error {
    case invalidAddress
    case invalidChain
}

final class PVScanInterator {
    weak var presenter: PVScanInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

extension PVScanInterator: PVScanInteractorInputProtocol {
    func process(accountScan: PolkadotVaultAccount) {
        do {
            let chainId = accountScan.genesisHash.toHex()

            // make sure that genesis hash is from valid chain

            guard let chain = chainRegistry.getChain(for: chainId), !chain.isEthereumBased else {
                throw PVScanInteratorError.invalidChain
            }

            // make sure address matches chain

            let accountId = try? accountScan.address.toAccountId(using: chain.chainFormat)

            guard accountId != nil else {
                throw PVScanInteratorError.invalidAddress
            }

            presenter?.didReceiveValidation(result: .success(accountScan))
        } catch {
            presenter?.didReceiveValidation(result: .failure(error))
        }
    }
}
