import Foundation
import Keystore_iOS
import Operation_iOS

final class GiftSubmissionFactoryFacade {
    private let selectedAccount: ChainAccountResponse
    private let chainAsset: ChainAsset
    private let signingWrapper: SigningWrapperProtocol
    private let giftsRepository: AnyDataProviderRepository<GiftModel>
    private let giftFactory: GiftOperationFactoryProtocol
    private let giftSecretsCleaningFactory: GiftSecretsCleaningProtocol
    private let persistExtrinsicService: PersistentExtrinsicServiceProtocol
    private let persistenceFilter: ExtrinsicPersistenceFilterProtocol
    private let eventCenter: EventCenterProtocol
    private let operationQueue: OperationQueue

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        signingWrapper: SigningWrapperProtocol,
        giftsRepository: AnyDataProviderRepository<GiftModel>,
        giftFactory: GiftOperationFactoryProtocol,
        giftSecretsCleaningFactory: GiftSecretsCleaningProtocol,
        persistExtrinsicService: PersistentExtrinsicServiceProtocol,
        persistenceFilter: ExtrinsicPersistenceFilterProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.signingWrapper = signingWrapper
        self.giftsRepository = giftsRepository
        self.giftFactory = giftFactory
        self.giftSecretsCleaningFactory = giftSecretsCleaningFactory
        self.persistExtrinsicService = persistExtrinsicService
        self.persistenceFilter = persistenceFilter
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }

    convenience init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        operationQueue: OperationQueue
    ) {
        let giftSecretsManager = GiftSecretsManager(keystore: Keychain())
        let giftFactory = GiftOperationFactory(
            metaId: selectedAccount.metaId,
            secretsManager: giftSecretsManager
        )

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount
        )

        let userRepositoryFactory = AccountRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )
        let giftsRepository = userRepositoryFactory.createGiftsRepository(for: nil)

        let persistentExtrinsicService = PersistentExtrinsicService(
            repository: SubstrateRepositoryFactory().createTxRepository(),
            operationQueue: operationQueue
        )

        self.init(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            signingWrapper: signingWrapper,
            giftsRepository: giftsRepository,
            giftFactory: giftFactory,
            giftSecretsCleaningFactory: giftSecretsManager,
            persistExtrinsicService: persistentExtrinsicService,
            persistenceFilter: AccountTypeExtrinsicPersistenceFilter(),
            eventCenter: EventCenter.shared,
            operationQueue: operationQueue
        )
    }
}

private extension GiftSubmissionFactoryFacade {
    func createSubmissionFactory() -> GiftSubmissionFactoryProtocol {
        GiftSubmissionFactory(
            giftsRepository: giftsRepository,
            giftFactory: giftFactory,
            giftSecretsCleaningFactory: giftSecretsCleaningFactory,
            persistExtrinsicService: persistExtrinsicService,
            persistenceFilter: persistenceFilter,
            eventCenter: eventCenter,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            operationQueue: operationQueue
        )
    }
}

extension GiftSubmissionFactoryFacade {
    func createSubstrateFactory(
        extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol
    ) -> SubstrateGiftSubmissionFactoryProtocol {
        SubstrateGiftSubmissionFactory(
            submissionFactory: createSubmissionFactory(),
            signingWrapper: signingWrapper,
            chainAsset: chainAsset,
            extrinsicMonitorFactory: extrinsicMonitorFactory,
            transferCommandFactory: SubstrateTransferCommandFactory()
        )
    }

    func createEvmFactory(
        transactionService: EvmTransactionServiceProtocol
    ) -> EvmGiftSubmissionFactoryProtocol {
        EvmGiftSubmissionFactory(
            submissionFactory: createSubmissionFactory(),
            signingWrapper: signingWrapper,
            chain: chainAsset.chain,
            transactionService: transactionService,
            transferCommandFactory: EvmTransferCommandFactory()
        )
    }
}
