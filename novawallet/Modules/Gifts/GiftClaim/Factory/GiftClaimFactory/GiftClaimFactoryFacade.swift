import Foundation
import Keystore_iOS
import Operation_iOS

final class GiftClaimFactoryFacade {
    private let signingWrapperFactory: SigningWrapperFactoryProtocol
    private let giftFactory: GiftOperationFactoryProtocol
    private let giftSecretManager: GiftSecretsManagerProtocol
    private let claimAvailabilityCheckFactory: GiftClaimAvailabilityCheckFactoryProtocol
    private let operationQueue: OperationQueue

    init(
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        giftFactory: GiftOperationFactoryProtocol,
        giftSecretManager: GiftSecretsManagerProtocol,
        claimAvailabilityCheckFactory: GiftClaimAvailabilityCheckFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.signingWrapperFactory = signingWrapperFactory
        self.giftFactory = giftFactory
        self.giftSecretManager = giftSecretManager
        self.claimAvailabilityCheckFactory = claimAvailabilityCheckFactory
        self.operationQueue = operationQueue
    }

    convenience init(
        operationQueue: OperationQueue,
        keystore: KeystoreProtocol
    ) {
        let giftSecretsManager = GiftSecretsManager(keystore: keystore)
        let giftFactory = GiftOperationFactory(
            metaId: nil,
            secretsManager: giftSecretsManager
        )

        let signingWrapperFactory = SigningWrapperFactory(keystore: keystore)

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let balanceQueryFactory = WalletRemoteQueryWrapperFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
        let assetStorageInfoFactory = AssetStorageInfoOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        let claimAvailabilityCheckFactory = GiftClaimAvailabilityCheckFactory(
            chainRegistry: chainRegistry,
            giftSecretsManager: giftSecretsManager,
            balanceQueryFactory: balanceQueryFactory,
            assetInfoFactory: assetStorageInfoFactory,
            operationQueue: operationQueue
        )

        self.init(
            signingWrapperFactory: signingWrapperFactory,
            giftFactory: giftFactory,
            giftSecretManager: giftSecretsManager,
            claimAvailabilityCheckFactory: claimAvailabilityCheckFactory,
            operationQueue: operationQueue
        )
    }
}

private extension GiftClaimFactoryFacade {
    func createClaimFactory() -> GiftClaimFactoryProtocol {
        GiftClaimFactory(
            giftFactory: giftFactory,
            giftSecretsCleaningFactory: giftSecretManager,
            claimAvailabilityCheckFactory: claimAvailabilityCheckFactory,
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
