import Foundation
import Keystore_iOS
import Operation_iOS

final class GiftClaimFactoryFacade {
    private let signingWrapperFactory: SigningWrapperFactoryProtocol
    private let giftFactory: GiftOperationFactoryProtocol
    private let giftSecretManager: GiftSecretsManagerProtocol
    private let operationQueue: OperationQueue

    init(
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        giftFactory: GiftOperationFactoryProtocol,
        giftSecretManager: GiftSecretsManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.signingWrapperFactory = signingWrapperFactory
        self.giftFactory = giftFactory
        self.giftSecretManager = giftSecretManager
        self.operationQueue = operationQueue
    }

    convenience init() {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let keyStore = Keychain()
        let giftSecretsManager = GiftSecretsManager(keystore: keyStore)
        let giftFactory = GiftOperationFactory(
            metaId: nil,
            secretsManager: giftSecretsManager
        )

        let signingWrapperFactory = SigningWrapperFactory()

        self.init(
            signingWrapperFactory: signingWrapperFactory,
            giftFactory: giftFactory,
            giftSecretManager: giftSecretsManager,
            operationQueue: operationQueue
        )
    }
}

private extension GiftClaimFactoryFacade {
    func createClaimFactory() -> GiftClaimFactoryProtocol {
        GiftClaimFactory(
            giftFactory: giftFactory,
            giftSecretsCleaningFactory: giftSecretManager,
            operationQueue: operationQueue
        )
    }
}

extension GiftClaimFactoryFacade {
    func createSubstrateFactory(
        extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol
    ) -> SubstrateGiftClaimFactoryProtocol {
        SubstrateGiftClaimFactory(
            claimFactory: createClaimFactory(),
            signingWrapperFactory: signingWrapperFactory,
            extrinsicMonitorFactory: extrinsicMonitorFactory,
            transferCommandFactory: SubstrateTransferCommandFactory(),
            operationQueue: operationQueue
        )
    }

    func createEvmFactory(
        transactionService: EvmTransactionServiceProtocol
    ) -> EvmGiftClaimFactoryProtocol {
        EvmGiftClaimFactory(
            claimFactory: createClaimFactory(),
            signingWrapperFactory: signingWrapperFactory,
            transactionService: transactionService,
            transferCommandFactory: EvmTransferCommandFactory()
        )
    }
}
