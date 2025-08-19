import Foundation
import Operation_iOS
import Keystore_iOS
import Foundation_iOS
import BigInt

class CommonMultisigHandler: CommonHandler {
    let payload: MultisigPayloadProtocol
    let chainId: ChainModel.Id
    let operationQueue: OperationQueue

    let callStore = CancellableCallStore()

    lazy var callFormattingFactory: CallFormattingOperationFactoryProtocol = {
        createCallFormattingOperationFactory(
            chainsRepository: chainsRepository,
            operationQueue: operationQueue
        )
    }()

    init(
        chainId: ChainModel.Id,
        payload: MultisigPayloadProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainId = chainId
        self.payload = payload
        self.operationQueue = operationQueue

        super.init()
    }

    func createTitle(using _: MultisigPayloadProtocol) -> String {
        fatalError("This method must be overridden by a subclass.")
    }

    func createBody(using _: MultisigPayloadProtocol) -> String {
        fatalError("This method must be overridden by a subclass.")
    }
}

// MARK: - Internal

extension CommonMultisigHandler {
    func handle(
        callbackQueue: DispatchQueue?,
        completion: @escaping (PushNotificationHandleResult) -> Void
    ) {
        let chainsOperation = chainsRepository.fetchAllOperation(with: .init())
        let settingsOperation = settingsRepository.fetchAllOperation(with: .init())

        let contentWrapper: CompoundOperationWrapper<NotificationContentResult> =
            OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) { [weak self] in
                guard let self else {
                    throw PushNotificationsHandlerErrors.undefined
                }

                let chains = try chainsOperation.extractNoCancellableResultData()
                let settings = try settingsOperation.extractNoCancellableResultData().first

                let fetchMetaAccountsOperation = self.walletsRepository().fetchAllOperation(with: .init())

                guard let chain = search(chainId: chainId, in: chains) else {
                    throw PushNotificationsHandlerErrors.chainNotFound(chainId: chainId)
                }

                let notificationContentWrapper = createNotificationContentWrapper(
                    wallets: settings?.wallets ?? [],
                    chain: chain,
                    metaAccounts: { try fetchMetaAccountsOperation.extractNoCancellableResultData() },
                    payload: self.payload
                )

                notificationContentWrapper.addDependency(operations: [fetchMetaAccountsOperation])

                return notificationContentWrapper.insertingHead(operations: [fetchMetaAccountsOperation])
            }

        contentWrapper.addDependency(operations: [chainsOperation])
        contentWrapper.addDependency(operations: [settingsOperation])

        let wrapper = contentWrapper
            .insertingHead(operations: [chainsOperation])
            .insertingHead(operations: [settingsOperation])

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: callbackQueue
        ) { result in
            switch result {
            case let .success(content):
                completion(.modified(content))
            case let .failure(error as PushNotificationsHandlerErrors):
                completion(.original(error))
            case let .failure(error):
                completion(.original(.internalError(error: error)))
            }
        }
    }
}

// MARK: - Private

private extension CommonMultisigHandler {
    func createNotificationContentWrapper(
        wallets: [Web3Alert.LocalWallet],
        chain: ChainModel,
        metaAccounts: @escaping () throws -> [MetaAccountModel],
        payload: MultisigPayloadProtocol
    ) -> CompoundOperationWrapper<NotificationContentResult> {
        let title = createTitle(using: payload)

        let walletNameOperation = ClosureOperation {
            self.targetWalletName(
                for: payload.multisigAddress,
                chainId: self.chainId,
                wallets: wallets,
                metaAccounts: try metaAccounts()
            )
        }

        guard let callData = payload.callData else {
            let mapOperation = ClosureOperation<NotificationContentResult> { [weak self] in
                guard let self else { throw BaseOperationError.parentOperationCancelled }

                let unknownOperationBody = R.string.localizable.pushNotificationMultisigUnknownBody(
                    chain.name.capitalized,
                    preferredLanguages: locale.rLanguages
                )

                return .init(
                    title: title,
                    subtitle: createSubtitle(with: try walletNameOperation.extractNoCancellableResultData()),
                    body: createBody(using: unknownOperationBody, adding: createBody(using: payload))
                )
            }

            mapOperation.addDependency(walletNameOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [walletNameOperation]
            )
        }

        let formattedCallWrapper = callFormattingFactory.createFormattingWrapper(
            for: callData,
            chainId: chain.chainId
        )

        let mapOperation = ClosureOperation<NotificationContentResult> { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let formattedCall = try formattedCallWrapper.targetOperation.extractNoCancellableResultData()

            let specificBodyPart = createBody(using: payload)
            let body = createBody(for: formattedCall, adding: specificBodyPart, chain: chain)

            return .init(
                title: title,
                subtitle: createSubtitle(with: try walletNameOperation.extractNoCancellableResultData()),
                body: body
            )
        }

        mapOperation.addDependency(walletNameOperation)
        mapOperation.addDependency(formattedCallWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [walletNameOperation] + formattedCallWrapper.allOperations
        )
    }

    func createSubtitle(with walletName: String?) -> String {
        if let walletName {
            R.string.localizable.pushNotificationCommonMultisigSubtitle(
                walletName,
                preferredLanguages: locale.rLanguages
            )
        } else {
            ""
        }
    }

    func createBody(
        for formattedCall: FormattedCall,
        adding operationSpecificPart: String,
        chain: ChainModel
    ) -> String {
        let commonBodyPart: String

        switch formattedCall.definition {
        case let .transfer(transfer):
            commonBodyPart = createTransferBodyContent(for: transfer, chain: chain)
        case let .batch(batch):
            commonBodyPart = createBatchBodyContent(for: batch, chain: chain)
        case let .general(general):
            commonBodyPart = createGeneralBodyContent(for: general, chain: chain)
        }

        return createBody(using: commonBodyPart, adding: operationSpecificPart)
    }

    func createBody(
        using commonBodyPart: String,
        adding operationSpecificPart: String
    ) -> String {
        [commonBodyPart, operationSpecificPart].joined(with: .space)
    }

    func createCallFormattingOperationFactory(
        chainsRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) -> CallFormattingOperationFactoryProtocol {
        let metadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem>
        metadataRepository = substrateStorageFacade.createRepository()

        let snapshotFactory = RuntimeDefaultTypesSnapshotFactory(
            repository: AnyDataProviderRepository(metadataRepository),
            runtimeTypeRegistryFactory: RuntimeTypeRegistryFactory(logger: Logger.shared)
        )

        let codingServiceProvider = OfflineRuntimeCodingServiceProvider(
            snapshotFactory: snapshotFactory,
            repository: chainsRepository,
            operationQueue: operationQueue
        )

        return CallFormattingOperationFactory(
            chainProvider: OfflineChainProvider(repository: chainsRepository),
            runtimeCodingServiceProvider: codingServiceProvider,
            walletRepository: walletsRepository(),
            operationQueue: operationQueue
        )
    }

    func createTransferBodyContent(
        for transfer: FormattedCall.Transfer,
        chain _: ChainModel
    ) -> String {
        let balance = balanceViewModel(
            asset: transfer.asset.asset,
            amount: String(transfer.amount),
            priceData: nil,
            workingQueue: operationQueue
        )

        let destinationAddress = try? transfer.account.accountId.toAddress(using: transfer.asset.chain.chainFormat)

        guard
            let amount = balance?.amount,
            let destinationAddress
        else { return "" }

        return R.string.localizable.pushNotificationMultisigTransferBody(
            amount,
            destinationAddress.mediumTruncated,
            transfer.asset.chain.name.capitalized,
            preferredLanguages: locale.rLanguages
        )
    }

    func createBatchBodyContent(
        for batch: FormattedCall.Batch,
        chain: ChainModel
    ) -> String {
        let batchTypeDescription = switch batch.type {
        case .batch:
            R.string.localizable.pushNotificationMultisigBatchBody(
                preferredLanguages: locale.rLanguages
            )
        case .batchAll:
            R.string.localizable.pushNotificationMultisigBatchAllBody(
                preferredLanguages: locale.rLanguages
            )
        case .forceBatch:
            R.string.localizable.pushNotificationMultisigForceBatchBody(
                preferredLanguages: locale.rLanguages
            )
        }

        let moduleCallInfo = createModuleCallInfo(for: batch.type.path)

        let fullBatchDescription = "\(moduleCallInfo) (\(batchTypeDescription))"

        return R.string.localizable.pushNotificationMultisigGeneralBody(
            fullBatchDescription,
            chain.name.capitalized,
            preferredLanguages: locale.rLanguages
        )
    }

    func createGeneralBodyContent(
        for generalDefinition: FormattedCall.General,
        chain: ChainModel
    ) -> String {
        R.string.localizable.pushNotificationMultisigGeneralBody(
            createModuleCallInfo(for: generalDefinition.callPath),
            chain.name.capitalized,
            preferredLanguages: locale.rLanguages
        )
    }

    func createModuleCallInfo(for callPath: CallCodingPath) -> String {
        [
            callPath.moduleName.displayModule,
            callPath.callName.displayCall
        ].joined(with: .colonSpace)
    }
}
