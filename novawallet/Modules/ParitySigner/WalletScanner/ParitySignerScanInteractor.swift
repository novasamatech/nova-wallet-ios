import Foundation
import Operation_iOS

enum ParitySignerScanInteratorError: Error {
    case invalidAddress
    case invalidChain
    case substrateKeysNotFound
    case ethereumKeysNotFound
}

final class ParitySignerScanInterator {
    weak var presenter: ParitySignerScanInteractorOutputProtocol?

    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }
}

private extension ParitySignerScanInterator {
    func proccess(singleAddress: ParitySignerWalletScan.SingleAddress) {
        do {
            let chainId = singleAddress.genesisHash.toHex()

            // make sure that genesis hash is from valid chain

            guard let chain = chainRegistry.getChain(for: chainId), !chain.isEthereumBased else {
                throw ParitySignerScanInteratorError.invalidChain
            }

            // make sure address matches chain

            let accountId = try? singleAddress.address.toAccountId(using: chain.chainFormat)

            guard let accountId else {
                throw ParitySignerScanInteratorError.invalidAddress
            }

            let model = ParitySignerWalletFormat.Single(
                substrateAccountId: accountId
            )

            presenter?.didReceiveValidation(result: .success(.single(model)))
        } catch {
            presenter?.didReceiveValidation(result: .failure(error))
        }
    }

    func process(rootKeysInfo: ParitySignerWalletScan.RootKeysInfo) {
        do {
            let rootKeys = rootKeysInfo.publicKeys

            guard let substrateKey = rootKeys.first(where: { $0.type != .ethereumEcdsa }) else {
                throw ParitySignerScanInteratorError.substrateKeysNotFound
            }

            guard let ethereumKey = rootKeys.first(where: { $0.type == .ethereumEcdsa }) else {
                throw ParitySignerScanInteratorError.ethereumKeysNotFound
            }

            let model = ParitySignerWalletFormat.RootKeys(
                substrate: substrateKey,
                ethereum: ethereumKey
            )

            presenter?.didReceiveValidation(result: .success(.rootKeys(model)))
        } catch {
            presenter?.didReceiveValidation(result: .failure(error))
        }
    }
}

extension ParitySignerScanInterator: ParitySignerScanInteractorInputProtocol {
    func process(walletScan: ParitySignerWalletScan) {
        switch walletScan {
        case let .singleAddress(singleAddress):
            proccess(singleAddress: singleAddress)
        case let .rootKeys(rootKeysInfo):
            process(rootKeysInfo: rootKeysInfo)
        }
    }
}
