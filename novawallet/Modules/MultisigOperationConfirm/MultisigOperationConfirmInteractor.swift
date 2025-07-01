import UIKit
import Operation_iOS

final class MultisigOperationConfirmInteractor {
    weak var presenter: MultisigOperationConfirmInteractorOutputProtocol?

    let operation: Multisig.PendingOperation
    let multisigWallet: MetaAccountModel
    let signatorWalletRepository: AnyDataProviderRepository<MetaAccountModel>
    let chainRegistry: ChainRegistryProtocol
    let callWeightEstimator: CallWeightEstimatingFactoryProtocol

    init(
        operation: Multisig.PendingOperation,
        multisigWallet: MetaAccountModel,
        signatorWalletRepository: AnyDataProviderRepository<MetaAccountModel>,
        chainRegistry: ChainRegistryProtocol,
        callWeightEstimator: CallWeightEstimatingFactoryProtocol
    ) {
        self.operation = operation
        self.multisigWallet = multisigWallet
        self.signatorWalletRepository = signatorWalletRepository
        self.chainRegistry = chainRegistry
        self.callWeightEstimator = callWeightEstimator
    }
}

extension MultisigOperationConfirmInteractor: MultisigOperationConfirmInteractorInputProtocol {}
