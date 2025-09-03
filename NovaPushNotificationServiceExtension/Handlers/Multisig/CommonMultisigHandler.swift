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

    func createTitle(params _: MultisigNotificationParams) -> String {
        fatalError("This method must be overridden by a subclass.")
    }

    func createBody(
        using _: MultisigPayloadProtocol,
        params _: MultisigNotificationParams
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

        let contentWrapper: CompoundOperationWrapper<NotificationContentResult> =
            OperationCombiningService.compoundNonOptionalWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                let chains = try chainsOperation.extractNoCancellableResultData()

                let fetchMetaAccountsOperation = self.walletsRepository().fetchAllOperation(with: .init())

                guard let chain = self.search(chainId: self.chainId, in: chains) else {
                    throw PushNotificationsHandlerErrors.chainNotFound(chainId: self.chainId)
                }

                let notificationContentWrapper = self.createNotificationContentWrapper(
                    chain: chain,
                    metaAccounts: { try fetchMetaAccountsOperation.extractNoCancellableResultData() },
                    payload: self.payload
                )

                notificationContentWrapper.addDependency(operations: [fetchMetaAccountsOperation])

                return notificationContentWrapper.insertingHead(operations: [fetchMetaAccountsOperation])
            }

        contentWrapper.addDependency(operations: [chainsOperation])

        let wrapper = contentWrapper
            .insertingHead(operations: [chainsOperation])

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
    ) -> AccountAddress {
        (try? address.toAccountId().toAddress(using: chain.chainFormat)) ?? address
    }

    func createNotificationParams(
        chain: ChainModel,
        metaAccounts: @escaping () throws -> [MetaAccountModel],
        payload: MultisigPayloadProtocol
    ) -> BaseOperation<MultisigNotificationParams> {
        ClosureOperation {
            guard
                let multisigWallet = self.targetWallet(
                    for: payload.multisigAddress,
                    chain: chain,
                    metaAccounts: try metaAccounts()
                ),
                let multisigAccount = multisigWallet.multisigAccount?.anyChainMultisig
            else { throw PushNotificationsHandlerErrors.undefined }

            let signatory = self.targetWallet(
                for: payload.signatoryAddress,
                chain: chain,
                metaAccounts: try metaAccounts()
            )?.name ?? self.convertAddress(payload.signatoryAddress, for: chain).mediumTruncated

            return MultisigNotificationParams(
                signatory: signatory,
                multisigName: multisigWallet.name,
                multisigAccount: multisigAccount
            )
        }
    }

    func createNotificationContentWrapper(
        chain: ChainModel,
        metaAccounts: @escaping () throws -> [MetaAccountModel],
        payload: MultisigPayloadProtocol
    ) -> CompoundOperationWrapper<NotificationContentResult> {
        let notificationParamsOperation = createNotificationParams(
            chain: chain,
            metaAccounts: metaAccounts,
            payload: payload
        )

        guard let callData = payload.callData else {
            let mapOperation = ClosureOperation<NotificationContentResult> {
                let unknownOperationBody = R.string(preferredLanguages: self.locale.rLanguages).localizable.pushNotificationMultisigUnknownBody(
                    chain.name.capitalized
                )
                let params = try notificationParamsOperation.extractNoCancellableResultData()
                let title = self.createTitle(params: params)
                let subtitle = self.createSubtitle(with: params.multisigName)
                let specificBodyPart = self.createBody(using: payload, params: params)
                let body = self.createBody(using: unknownOperationBody, adding: specificBodyPart)

                return .init(title: title, subtitle: subtitle, body: body)
            }

            mapOperation.addDependency(notificationParamsOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [notificationParamsOperation]
            )
        }

        let formattedCallWrapper = callFormattingFactory.createFormattingWrapper(
            for: callData,
            chainId: chain.chainId
        )

        let mapOperation = ClosureOperation<NotificationContentResult> {
            let formattedCall = try formattedCallWrapper.targetOperation.extractNoCancellableResultData()

            let params = try notificationParamsOperation.extractNoCancellableResultData()
            let title = self.createTitle(params: params)
            let subtitle = self.createSubtitle(with: params.multisigName)
            let specificBodyPart = self.createBody(using: payload, params: params)
            let body = self.createBody(for: formattedCall, adding: specificBodyPart, chain: chain)

            return .init(title: title, subtitle: subtitle, body: body)
        }

        mapOperation.addDependency(notificationParamsOperation)
        mapOperation.addDependency(formattedCallWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [notificationParamsOperation] + formattedCallWrapper.allOperations
        )
    }

    func createSubtitle(with walletName: String?) -> String {
        if let walletName {
            R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationCommonMultisigSubtitle(
                walletName
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
            let delegatedNameOrAddress = delegatedAccount.name
            ?? (try? delegatedAccount.accountId.toAddress(using: chain.chainFormat))?.mediumTruncated
        else {
            return createBody(using: commonPart, adding: operationSpecificPart)
        }

        let delegatedAccountPart = [
            R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationOnBehalfOf(),
            delegatedNameOrAddress
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

        return R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationMultisigTransferBody(
            amount,
            destination,
            transfer.asset.chain.name.capitalized
        )
    }

    func createBatchBodyContent(
        for batch: FormattedCall.Batch,
        chain: ChainModel
    ) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationMultisigGeneralBody(
            batch.type.fullModuleCallDescription.value(for: locale),
            chain.name.capitalized
        )
    }

    func createGeneralBodyContent(
        for generalDefinition: FormattedCall.General,
        chain: ChainModel
    ) -> String {
        R.string(preferredLanguages: locale.rLanguages).localizable.pushNotificationMultisigGeneralBody(
            createModuleCallInfo(for: generalDefinition.callPath),
            chain.name.capitalized
        )
    }

    func createModuleCallInfo(for callPath: CallCodingPath) -> String {
        [
            callPath.moduleName.displayModule,
            callPath.callName.displayCall
        ].joined(with: .colonSpace)
    }
}
