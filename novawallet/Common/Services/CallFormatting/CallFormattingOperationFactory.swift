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

    func performFormatting(
        of json: JSON,
        localAccounts: [AccountId: MetaChainAccountResponse],
        context: RuntimeJsonContext
    ) throws -> FormattedCall {
        let decodedCall = try ExtrinsicExtraction.getCall(from: json, context: context)

        let (delegatedAccountId, runtimeCall) = try NestedCallMapper().mapProxiedAndCall(call: json, context: context)

        let generalFormat = FormattedCall.General(callPath: runtimeCall.path)

        let delegatedAccount = delegatedAccountId.map { resolveAccount(for: $0, localAccounts: localAccounts) }

        return FormattedCall(
            definition: .general(generalFormat),
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
