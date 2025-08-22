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

    func createBody(
        using _: MultisigPayloadProtocol,
        walletNames _: MultisigNotificationAccounts
    ) -> String {
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
            ) {
                let chains = try chainsOperation.extractNoCancellableResultData()
                let settings = try settingsOperation.extractNoCancellableResultData().first

                let fetchMetaAccountsOperation = self.walletsRepository().fetchAllOperation(with: .init())

                guard let chain = self.search(chainId: self.chainId, in: chains) else {
                    throw PushNotificationsHandlerErrors.chainNotFound(chainId: self.chainId)
                }

                let notificationContentWrapper = self.createNotificationContentWrapper(
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
    func convertAddress(
        _ address: String,
        for chain: ChainModel
    ) -> AccountAddress? {
        try? address
            .toAccountId()
            .toAddress(using: chain.chainFormat)
    }

    func createWalletNamesOperation(
        wallets: [Web3Alert.LocalWallet],
        chain: ChainModel,
        metaAccounts: @escaping () throws -> [MetaAccountModel],
        payload: MultisigPayloadProtocol
    ) -> BaseOperation<MultisigNotificationAccounts> {
        ClosureOperation {
            let multisig = self.targetWalletName(
                for: payload.multisigAddress,
                chainId: self.chainId,
                wallets: wallets,
                metaAccounts: try metaAccounts()
            ) ?? payload.multisigAddress

            let signatory = self.targetWalletName(
                for: payload.signatoryAddress,
                chainId: self.chainId,
                wallets: wallets,
                metaAccounts: try metaAccounts()
            ) ?? self.convertAddress(payload.signatoryAddress, for: chain)?.mediumTruncated

            return MultisigNotificationAccounts(
                signatory: signatory,
                multisig: multisig
            )
        }
    }

    func createNotificationContentWrapper(
        wallets: [Web3Alert.LocalWallet],
        chain: ChainModel,
        metaAccounts: @escaping () throws -> [MetaAccountModel],
        payload: MultisigPayloadProtocol
    ) -> CompoundOperationWrapper<NotificationContentResult> {
        let title = createTitle(using: payload)

        let walletNamesOperation = createWalletNamesOperation(
            wallets: wallets,
            chain: chain,
            metaAccounts: metaAccounts,
            payload: payload
        )

        guard let callData = payload.callData else {
            let mapOperation = ClosureOperation<NotificationContentResult> {
                let unknownOperationBody = R.string.localizable.pushNotificationMultisigUnknownBody(
                    chain.name.capitalized,
                    preferredLanguages: self.locale.rLanguages
                )
                let walletNames = try walletNamesOperation.extractNoCancellableResultData()
                let subtitle = self.createSubtitle(with: walletNames.multisig)
                let body = self.createBody(
                    using: unknownOperationBody,
                    adding: self.createBody(using: payload, walletNames: walletNames)
                )

                return .init(
                    title: title,
                    subtitle: subtitle,
                    body: body
                )
            }

            mapOperation.addDependency(walletNamesOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [walletNamesOperation]
            )
        }

        let formattedCallWrapper = callFormattingFactory.createFormattingWrapper(
            for: callData,
            chainId: chain.chainId
        )

        let mapOperation = ClosureOperation<NotificationContentResult> {
            let formattedCall = try formattedCallWrapper.targetOperation.extractNoCancellableResultData()

            let walletNames = try walletNamesOperation.extractNoCancellableResultData()
            let subtitle = self.createSubtitle(with: walletNames.multisig)
            let specificBodyPart = self.createBody(using: payload, walletNames: walletNames)
            let body = self.createBody(for: formattedCall, adding: specificBodyPart, chain: chain)

            return .init(
                title: title,
                subtitle: subtitle,
                body: body
            )
        }

        mapOperation.addDependency(walletNamesOperation)
        mapOperation.addDependency(formattedCallWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [walletNamesOperation] + formattedCallWrapper.allOperations
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
        let commonPart: String

        switch formattedCall.definition {
        case let .transfer(transfer):
            commonPart = createTransferBodyContent(for: transfer)
        case let .batch(batch):
            commonPart = createBatchBodyContent(for: batch, chain: chain)
        case let .general(general):
            commonPart = createGeneralBodyContent(for: general, chain: chain)
        }

        guard
            let delegatedAccount = formattedCall.delegatedAccount,
            let delegatedAddress = try? delegatedAccount.accountId.toAddress(using: chain.chainFormat)
        else {
            return createBody(using: commonPart, adding: operationSpecificPart)
        }

        let delegatedAccountPart = [
            R.string.localizable.pushNotificationOnBehalfOf(preferredLanguages: locale.rLanguages),
            delegatedAddress.mediumTruncated
        ].joined(with: .space)

        let delegatedCommonPart = [
            commonPart,
            delegatedAccountPart
        ].joined(with: .newLine)

        return createBody(using: delegatedCommonPart, adding: operationSpecificPart)
    }

    func createBody(
        using commonBodyPart: String,
        adding operationSpecificPart: String
    ) -> String {
        [commonBodyPart, operationSpecificPart].joined(with: .newLine)
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

    func createTransferBodyContent(for transfer: FormattedCall.Transfer) -> String {
        let balance = balanceViewModel(
            asset: transfer.asset.asset,
            amount: String(transfer.amount),
            priceData: nil,
            workingQueue: operationQueue
        )

        let destination = switch transfer.account {
        case let .local(chainAccountResponse):
            chainAccountResponse.chainAccount.name
        case let .remote(accountId):
            try? accountId.toAddress(using: transfer.asset.chain.chainFormat).mediumTruncated
        }

        guard
            let amount = balance?.amount,
            let destination
        else { return "" }

        return R.string.localizable.pushNotificationMultisigTransferBody(
            amount,
            destination,
            transfer.asset.chain.name.capitalized,
            preferredLanguages: locale.rLanguages
        )
    }

    func createBatchBodyContent(
        for batch: FormattedCall.Batch,
        chain: ChainModel
    ) -> String {
        R.string.localizable.pushNotificationMultisigGeneralBody(
            batch.type.fullModuleCallDescription.value(for: locale),
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
