import UIKit
import RobinHood
import IrohaCrypto

enum AccountExportPasswordInteractorError: Error {
    case missingAccount
    case invalidResult
    case unsupportedAddress
}

final class AccountExportPasswordInteractor {
    weak var presenter: AccountExportPasswordInteractorOutputProtocol!

    let exportJsonWrapper: KeystoreExportWrapperProtocol
    let metaAccount: MetaAccountModel
    let chain: ChainModel
    let operationManager: OperationManagerProtocol

    init(
        metaAccount: MetaAccountModel,
        chain: ChainModel,
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
            guard
                let metaAccount = self?.metaAccount,
                let chain = self?.chain,
                let cryptoType = metaAccount.fetch(for: chain.accountRequest())?.cryptoType else {
                throw AccountExportPasswordInteractorError.missingAccount
            }

            guard let data = try self?.exportJsonWrapper.export(
                metaAccount: metaAccount,
                chain: chain,
                password: password
            ) else {
                throw BaseOperationError.parentOperationCancelled
            }

            guard let result = String(data: data, encoding: .utf8) else {
                throw AccountExportPasswordInteractorError.invalidResult
            }

            return RestoreJson(
                data: result,
                chain: chain,
                cryptoType: cryptoType
            )
        }

        exportOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let model = try exportOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                    self?.presenter.didExport(json: model)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [exportOperation], in: .transient)
    }
}
