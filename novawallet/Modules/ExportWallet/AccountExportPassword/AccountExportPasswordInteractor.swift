import UIKit
import Operation_iOS
import NovaCrypto

enum AccountExportPasswordInteractorError: Error {
    case missingAccount
    case invalidResult
    case unsupportedAddress
}

final class AccountExportPasswordInteractor {
    weak var presenter: AccountExportPasswordInteractorOutputProtocol!

    let exportJsonWrapper: KeystoreExportWrapperProtocol
    let metaAccount: MetaAccountModel
    let chain: ChainModel?
    let operationManager: OperationManagerProtocol

    init(
        metaAccount: MetaAccountModel,
        chain: ChainModel?,
        exportJsonWrapper: KeystoreExportWrapperProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.metaAccount = metaAccount
        self.chain = chain
        self.exportJsonWrapper = exportJsonWrapper
        self.operationManager = operationManager
    }
}

extension AccountExportPasswordInteractor: AccountExportPasswordInteractorInputProtocol {
    func exportAccount(password: String) {
        let exportOperation: BaseOperation<RestoreJson> = ClosureOperation { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let cryptoType: MultiassetCryptoType

            if let chain {
                guard let accountResponse = metaAccount.fetch(for: chain.accountRequest()) else {
                    throw AccountExportPasswordInteractorError.missingAccount
                }

                cryptoType = accountResponse.cryptoType
            } else {
                guard let substrateCryptoType = metaAccount.substrateMultiAssetCryptoType else {
                    throw CommonError.dataCorruption
                }

                cryptoType = substrateCryptoType
            }

            let data = try exportJsonWrapper.export(
                metaAccount: metaAccount,
                chain: chain,
                password: password
            )

            guard let result = String(data: data, encoding: .utf8) else {
                throw AccountExportPasswordInteractorError.invalidResult
            }

            return RestoreJson(data: result, chain: chain, cryptoType: cryptoType)
        }

        exportOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let model = try exportOperation.extractNoCancellableResultData()

                    self?.presenter.didExport(json: model)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [exportOperation], in: .transient)
    }
}
