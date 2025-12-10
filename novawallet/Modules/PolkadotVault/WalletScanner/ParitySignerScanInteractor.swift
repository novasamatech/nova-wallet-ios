import Foundation
import Operation_iOS

enum ParitySignerScanInteratorError: Error {
    case invalidAddress
    case invalidChain
}

final class PolkadotVaultScanInterator {
    weak var presenter: PolkadotVaultScanInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

extension PolkadotVaultScanInterator: PolkadotVaultScanInteractorInputProtocol {
    func process(accountScan: PolkadotVaultAccountScan) {
        do {
            let chainId = accountScan.genesisHash.toHex()

            // make sure that genesis hash is from valid chain

            guard let chain = chainRegistry.getChain(for: chainId), !chain.isEthereumBased else {
                throw ParitySignerScanInteratorError.invalidChain
            }

            // make sure address matches chain

            let accountId = try? addressScan.address.toAccountId(using: chain.chainFormat)

            guard accountId != nil else {
                throw ParitySignerScanInteratorError.invalidAddress
            }

            presenter?.didReceiveValidation(result: .success(addressScan))
        } catch {
            presenter?.didReceiveValidation(result: .failure(error))
        }
    }
}
