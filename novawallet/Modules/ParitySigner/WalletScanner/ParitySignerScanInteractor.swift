import Foundation
import Operation_iOS

final class ParitySignerScanInterator {
    weak var presenter: ParitySignerScanInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol
    let type: ParitySignerType

    init(chainRegistry: ChainRegistryProtocol, type: ParitySignerType) {
        self.chainRegistry = chainRegistry
        self.type = type
    }
}

extension ParitySignerScanInterator: ParitySignerScanInteractorInputProtocol {
    func process(walletUpdate: PolkadotVaultWalletUpdate) {
        do {
            switch type {
            case .legacy:
                try walletUpdate.ensureSingleAccount()
            case .vault:
                try walletUpdate.ensureSingleAccountPerChain()
            }

            try walletUpdate.ensurePublicKeysValid()

            presenter?.didReceiveValidation(result: .success(walletUpdate))
        } catch {
            presenter?.didReceiveValidation(result: .failure(error))
        }
    }
}
