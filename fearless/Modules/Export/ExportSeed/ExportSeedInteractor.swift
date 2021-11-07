import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto

enum ExportSeedInteractorError: Error {
    case missingSeed
}

final class ExportSeedInteractor {
    weak var presenter: ExportSeedInteractorOutputProtocol!

    let keystore: KeystoreProtocol
    let metaAccount: MetaAccountModel
    let chain: ChainModel
    let operationManager: OperationManagerProtocol

    init(
        metaAccount: MetaAccountModel,
        chain: ChainModel,
        keystore: KeystoreProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.keystore = keystore
        self.metaAccount = metaAccount
        self.chain = chain
        self.operationManager = operationManager
    }
}

extension ExportSeedInteractor: ExportSeedInteractorInputProtocol {
    func fetchExportDataForAddress() {
        let exportOperation: BaseOperation<ExportSeedData> = ClosureOperation { [weak self] in
            guard
                let metaAccount = self?.metaAccount,
                let chain = self?.chain,
                let accountResponse = metaAccount.fetch(for: chain.accountRequest()) else {
                throw ExportMnemonicInteractorError.missingAccount
            }

            let accountId = metaAccount.fetchChainAccountId(for: chain.accountRequest())
            let seedTag = chain.isEthereumBased ?
                KeystoreTagV2.ethereumSeedTagForMetaId(metaAccount.metaId, accountId: accountId) :
                KeystoreTagV2.substrateSeedTagForMetaId(metaAccount.metaId, accountId: accountId)
            var optionalSeed: Data? = try self?.keystore.loadIfKeyExists(seedTag)

            if optionalSeed == nil, accountResponse.cryptoType.supportsSeedFromSecretKey {
                let secretTag = chain.isEthereumBased ?
                    KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaAccount.metaId, accountId: accountId) :
                    KeystoreTagV2.substrateSecretKeyTagForMetaId(metaAccount.metaId, accountId: accountId)
                optionalSeed = try self?.keystore.loadIfKeyExists(secretTag)
            }

            guard let seed = optionalSeed else {
                throw ExportSeedInteractorError.missingSeed
            }

            let derivationTag = chain.isEthereumBased ?
                KeystoreTagV2.ethereumDerivationTagForMetaId(metaAccount.metaId, accountId: accountId) :
                KeystoreTagV2.substrateDerivationTagForMetaId(metaAccount.metaId, accountId: accountId)

            let derivationPath: String?

            if let derivationPathData = try self?.keystore.loadIfKeyExists(derivationTag) {
                derivationPath = String(data: derivationPathData, encoding: .utf8)
            } else {
                derivationPath = nil
            }

            return ExportSeedData(
                metaAccount: metaAccount,
                seed: seed,
                derivationPath: derivationPath,
                chain: chain
            )
        }

        exportOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let model = try exportOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                    self?.presenter.didReceive(exportData: model)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [exportOperation], in: .transient)
    }
}
