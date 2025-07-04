import Foundation
import Operation_iOS
import SubstrateSdk

protocol CallFormattingOperationFactoryProtocol {
    func createFormattingWrapper(
        for callData: Substrate.CallData,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<FormattedCall>
}

final class CallFormattingOperationFactory {
    let chainRegistry: ChainRegistryProtocol
    let walletRepository: AnyDataProviderRepository<MetaAccountModel>

    init(
        chainRegistry: ChainRegistryProtocol,
        walletRepository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        self.chainRegistry = chainRegistry
        self.walletRepository = walletRepository
    }
}

private extension CallFormattingOperationFactory {
    func resolveAccount(
        for accountId: AccountId,
        localAccounts: [AccountId: MetaChainAccountResponse]
    ) -> FormattedCall.Account {
        if let account = localAccounts[accountId] {
            return .local(account)
        } else {
            return .remote(accountId)
        }
    }

    func detectNativeTransfer(
        from call: AnyRuntimeCall,
        chain: ChainModel,
        localAccounts: [AccountId: MetaChainAccountResponse],
        context: RuntimeJsonContext
    ) -> FormattedCall.Definition? {
        guard
            call.path.isBalancesTransfer,
            let transferArgs = try? call.args.map(
                to: TransferCall.self,
                with: context.toRawContext()
            ),
            let accountId = transferArgs.dest.accountId,
            let nativeAsset = chain.utilityChainAsset() else {
            return nil
        }

        let account: FormattedCall.Account = if let localAccount = localAccounts[accountId] {
            .local(localAccount)
        } else {
            .remote(accountId)
        }

        let transfer = FormattedCall.Transfer(
            amount: transferArgs.value,
            account: account,
            asset: nativeAsset
        )

        return .transfer(transfer)
    }

    func detectTransfer(
        from call: AnyRuntimeCall,
        chain: ChainModel,
        localAccounts: [AccountId: MetaChainAccountResponse],
        context: RuntimeJsonContext
    ) -> FormattedCall.Definition? {
        if let native = detectNativeTransfer(
            from: call,
            chain: chain,
            localAccounts: localAccounts,
            context: context
        ) {
            return native
        } else {
            return nil
        }
    }

    func resolveDefinition(
        for call: AnyRuntimeCall,
        chain: ChainModel,
        localAccounts: [AccountId: MetaChainAccountResponse],
        context: RuntimeJsonContext
    ) -> FormattedCall.Definition {
        if let transfer = detectTransfer(
            from: call,
            chain: chain,
            localAccounts: localAccounts,
            context: context
        ) {
            return transfer
        } else {
            let general = FormattedCall.General(callPath: call.path)

            return .general(general)
        }
    }

    func performFormatting(
        of json: JSON,
        chain: ChainModel,
        localAccounts: [AccountId: MetaChainAccountResponse],
        context: RuntimeJsonContext
    ) throws -> FormattedCall {
        let decodedCall = try ExtrinsicExtraction.getCall(from: json, context: context)

        let (delegatedAccountId, runtimeCall) = try NestedCallMapper().mapProxiedAndCall(call: json, context: context)

        let definition = resolveDefinition(
            for: runtimeCall,
            chain: chain,
            localAccounts: localAccounts,
            context: context
        )

        let delegatedAccount = delegatedAccountId.map { resolveAccount(for: $0, localAccounts: localAccounts) }

        return FormattedCall(
            definition: definition,
            delegatedAccount: delegatedAccount,
            decoded: decodedCall
        )
    }
}

extension CallFormattingOperationFactory: CallFormattingOperationFactoryProtocol {
    func createFormattingWrapper(
        for callData: Substrate.CallData,
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<FormattedCall> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)
            let chain = try chainRegistry.getChainOrError(for: chainId)

            let localAccountsWrapper = walletRepository.createWalletsWrapperByAccountId(for: chain)

            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
            let decodingWrapper: CompoundOperationWrapper<JSON> = runtimeProvider.createDecodingWrapper(
                for: callData,
                of: GenericType.call.name
            )

            let formattingOperation = ClosureOperation<FormattedCall> {
                let jsonCall = try decodingWrapper.targetOperation.extractNoCancellableResultData()
                let localAccounts = try localAccountsWrapper.targetOperation.extractNoCancellableResultData()
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                return try self.performFormatting(
                    of: jsonCall,
                    chain: chain,
                    localAccounts: localAccounts,
                    context: codingFactory.createRuntimeJsonContext()
                )
            }

            formattingOperation.addDependency(decodingWrapper.targetOperation)
            formattingOperation.addDependency(codingFactoryOperation)
            formattingOperation.addDependency(localAccountsWrapper.targetOperation)

            return decodingWrapper
                .insertingHead(operations: localAccountsWrapper.allOperations)
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: formattingOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
