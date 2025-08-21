import Foundation
import Foundation_iOS
import Operation_iOS
import BigInt

final class MultisigNotificationMessageHandler: WalletSelectingNotificationHandling {
    let chainRegistry: ChainRegistryProtocol
    let settings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol
    let settingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>
    let walletsRepository: AnyDataProviderRepository<MetaAccountModel>
    let callFormattingFactory: CallFormattingOperationFactoryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue

    let callStore = CancellableCallStore()

    init(
        chainRegistry: ChainRegistryProtocol,
        settings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol,
        settingsRepository: AnyDataProviderRepository<Web3Alert.LocalSettings>,
        walletsRepository: AnyDataProviderRepository<MetaAccountModel>,
        callFormattingFactory: CallFormattingOperationFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue
    ) {
        self.chainRegistry = chainRegistry
        self.settings = settings
        self.eventCenter = eventCenter
        self.settingsRepository = settingsRepository
        self.walletsRepository = walletsRepository
        self.callFormattingFactory = callFormattingFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }
}

// MARK: - Private

private extension MultisigNotificationMessageHandler {
    func handleOperationOpen(
        chainId: ChainModel.Id,
        payload: MultisigPayloadProtocol,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        getChain(for: chainId) { [weak self] chain in
            self?.handleOperationOpen(
                chain: chain,
                payload: payload,
                completion: completion
            )
        }
    }

    func handleOperationExecuted(
        chainId: ChainModel.Id,
        payload: MultisigPayloadProtocol,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        getChain(for: chainId) { [weak self] chain in
            self?.handleOperationExecuted(
                chain: chain,
                callData: payload.callData,
                completion: completion
            )
        }
    }

    func handleOperationCancelled(
        chainId: ChainModel.Id,
        payload: MultisigPayloadProtocol,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        getChain(for: chainId) { [weak self] chain in
            self?.handleOperationCancelled(
                chain: chain,
                cancellerAddress: payload.signatoryAddress,
                callData: payload.callData,
                completion: completion
            )
        }
    }

    func getChain(
        for chainId: ChainModel.Id,
        completion: @escaping (ChainModel) -> Void
    ) {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: workingQueue
        ) { [weak self] changes in
            guard let self else { return }

            let chains: [ChainModel] = changes.allChangedItems()

            guard let chain = chains.first(where: {
                Web3Alert.createRemoteChainId(from: $0.chainId) == chainId
            }) else {
                return
            }

            chainRegistry.chainsUnsubscribe(self)

            completion(chain)
        }
    }

    func handleOperationOpen(
        chain: ChainModel,
        payload: MultisigPayloadProtocol,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        guard
            let multisigAccountId = try? payload.multisigAddress.toAccountId(),
            let signatoryAccountId = try? payload.signatoryAddress.toAccountId()
        else {
            completion(.failure(MultisigNotificationHandlingError.invalidAddress))
            return
        }

        let key = Multisig.PendingOperation.Key(
            callHash: payload.callHash,
            chainId: chain.chainId,
            multisigAccountId: multisigAccountId
        )

        trySelectWallet(
            with: payload.multisigAddress,
            chainId: chain.chainId,
            filter: { $0.multisigAccount?.anyChainMultisig?.signatory != signatoryAccountId },
            successClosure: { completion(.success(.multisigOperationDetails(.key(key)))) },
            failureClosure: { completion(.failure($0)) }
        )
    }

    func handleOperationExecuted(
        chain: ChainModel,
        callData: Substrate.CallData?,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        guard let callData else {
            return
        }

        let formattedCallWrapper = callFormattingFactory.createFormattingWrapper(
            for: callData,
            chainId: chain.chainId
        )

        let resultOperation = ClosureOperation {
            let formattedCall = try formattedCallWrapper.targetOperation.extractNoCancellableResultData()
            let messageModel = self.createExecutedMessageModel(
                for: formattedCall,
                chain: chain
            )

            completion(.success(.multisigOperationEnded(messageModel)))
        }
    }

    func handleOperationCancelled(
        chain: ChainModel,
        cancellerAddress: AccountAddress,
        callData: Substrate.CallData?,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        guard let callData else {
            return
        }

        let formattedCallWrapper = callFormattingFactory.createFormattingWrapper(
            for: callData,
            chainId: chain.chainId
        )

        let resultOperation = ClosureOperation {
            let formattedCall = try formattedCallWrapper.targetOperation.extractNoCancellableResultData()
            let messageModel = self.createRejectedMessageModel(
                for: formattedCall,
                cancellerAddress: cancellerAddress,
                chain: chain
            )

            completion(.success(.multisigOperationEnded(messageModel)))
        }
    }

    func createFormattedCommonBody(
        from formattedCall: FormattedCall,
        adding operationSpecificPart: LocalizableResource<String>,
        chain: ChainModel
    ) -> LocalizableResource<String> {
        let commonPart: LocalizableResource<String>

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

        let delegatedCommonPart = createDelegatedCommonPart(
            using: commonPart,
            delegatedAddress: delegatedAddress
        )

        return createBody(using: delegatedCommonPart, adding: operationSpecificPart)
    }

    func createExecutedBodySpecificPart() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.multisigOperationNoActionsRequired(
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func createRejectedBodySpecificPart(cancellerAddress: AccountAddress) -> LocalizableResource<String> {
        LocalizableResource { locale in
            [
                R.string.localizable.multisigOperationFormatCancelledText(
                    cancellerAddress.mediumTruncated,
                    preferredLanguages: locale.rLanguages
                ),
                R.string.localizable.multisigOperationNoActionsRequired(
                    preferredLanguages: locale.rLanguages
                )
            ].joined(with: .newLine)
        }
    }

    func createBody(
        using commonBodyPart: LocalizableResource<String>,
        adding operationSpecificPart: LocalizableResource<String>
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            [
                commonBodyPart.value(for: locale),
                operationSpecificPart.value(for: locale)
            ].joined(with: .newLine)
        }
    }

    func createDelegatedCommonPart(
        using commonPart: LocalizableResource<String>,
        delegatedAddress: String
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            let delegatedAccountPart = [
                R.string.localizable.delegatedAccountOnBehalfOf(preferredLanguages: locale.rLanguages),
                delegatedAddress.mediumTruncated
            ].joined(with: .space)

            let delegatedCommonPart = [
                commonPart.value(for: locale),
                delegatedAccountPart
            ].joined(with: .newLine)

            return delegatedCommonPart
        }
    }

    func createTransferBodyContent(for transfer: FormattedCall.Transfer) -> LocalizableResource<String> {
        LocalizableResource { locale in
            let balance = self.balanceViewModel(
                asset: transfer.asset.asset,
                amount: String(transfer.amount),
                priceData: nil
            )?.value(for: locale)

            let destinationAddress = try? transfer.account.accountId.toAddress(using: transfer.asset.chain.chainFormat)

            guard
                let amount = balance?.amount,
                let destinationAddress
            else { return "" }

            return R.string.localizable.multisigOperationFormatTransferText(
                amount,
                destinationAddress.mediumTruncated,
                transfer.asset.chain.name.capitalized,
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func createBatchBodyContent(
        for batch: FormattedCall.Batch,
        chain: ChainModel
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.multisigOperationFormatGeneralText(
                batch.type.fullModuleCallDescription.value(for: locale),
                chain.name.capitalized,
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func createGeneralBodyContent(
        for generalDefinition: FormattedCall.General,
        chain: ChainModel
    ) -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.multisigOperationFormatGeneralText(
                self.createModuleCallInfo(for: generalDefinition.callPath),
                chain.name.capitalized,
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func createModuleCallInfo(for callPath: CallCodingPath) -> String {
        [
            callPath.moduleName.displayModule,
            callPath.callName.displayCall
        ].joined(with: .colonSpace)
    }

    func createExecutedTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.commonMultisigExecuted(preferredLanguages: locale.rLanguages)
        }
    }

    func createRejectedTitle() -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.commonMultisigRejected(preferredLanguages: locale.rLanguages)
        }
    }

    func createExecutedMessageModel(
        for formattedCall: FormattedCall,
        chain: ChainModel
    ) -> MultisigEndedMessageModel {
        let title = createExecutedTitle()
        let body = createFormattedCommonBody(
            from: formattedCall,
            adding: createExecutedBodySpecificPart(),
            chain: chain
        )
        let messageModel = MultisigEndedMessageModel { locale in
            .init(
                title: title.value(for: locale),
                description: body.value(for: locale)
            )
        }

        return messageModel
    }

    func createRejectedMessageModel(
        for formattedCall: FormattedCall,
        cancellerAddress: AccountAddress,
        chain: ChainModel
    ) -> MultisigEndedMessageModel {
        let title = createRejectedTitle()
        let body = createFormattedCommonBody(
            from: formattedCall,
            adding: createRejectedBodySpecificPart(cancellerAddress: cancellerAddress),
            chain: chain
        )
        let messageModel = MultisigEndedMessageModel { locale in
            .init(
                title: title.value(for: locale),
                description: body.value(for: locale)
            )
        }

        return messageModel
    }

    func balanceViewModel(
        asset: AssetModel,
        amount: String,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        guard
            let currencyManager = CurrencyManager.shared,
            let amountInPlank = BigUInt(amount) else {
            return nil
        }
        let decimalAmount = amountInPlank.decimal(precision: asset.precision)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let factory = PrimitiveBalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory,
            formatterFactory: AssetBalanceFormatterFactory()
        )

        return factory.balanceFromPrice(
            decimalAmount,
            priceData: priceData
        )
    }
}

// MARK: - PushNotificationMessageHandlingProtocol

extension MultisigNotificationMessageHandler: PushNotificationMessageHandlingProtocol {
    func handle(
        message: NotificationMessage,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    ) {
        switch message {
        case let .newMultisig(chainId, payload), let .multisigApproval(chainId, payload):
            handleOperationOpen(
                chainId: chainId,
                payload: payload,
                completion: completion
            )
        case let .multisigExecuted(chainId, payload):
            handleOperationExecuted(
                chainId: chainId,
                payload: payload,
                completion: completion
            )
        case let .multisigCancelled(chainId, payload):
            handleOperationCancelled(
                chainId: chainId,
                payload: payload,
                completion: completion
            )
        default:
            completion(.failure(MultisigNotificationHandlingError.unsupportedMessage))
            return
        }
    }

    func cancel() {
        chainRegistry.chainsUnsubscribe(self)
    }
}
