import Foundation
import RobinHood

enum ParitySignerScanInteratorError: Error {
    case invalidAddress
    case invalidChain
}

final class ParitySignerScanInterator {
    weak var presenter: ParitySignerScanInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

extension ParitySignerScanInterator: ParitySignerScanInteractorInputProtocol {
    func process(addressScan: ParitySignerAddressScan) {
        do {
            let chainId = addressScan.genesisHash.toHex()

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
