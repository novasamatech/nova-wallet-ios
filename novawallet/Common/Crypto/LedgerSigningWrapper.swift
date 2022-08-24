import Foundation
import IrohaCrypto

final class LedgerSigningWrapper {
    let uiPresenter: TransactionSigningPresenting
    let metaId: String
    let chainId: ChainModel.Id

    init(
        uiPresenter: TransactionSigningPresenting,
        metaId: String,
        chainId: ChainModel.Id
    ) {
        self.uiPresenter = uiPresenter
        self.metaId = metaId
        self.chainId = chainId
    }
}

extension LedgerSigningWrapper {
    func sign(_: Data) throws -> IRSignatureProtocol {
        // TODO: Add support for Ledger signing
        throw HardwareSigningError.signingCancelled
    }
}
