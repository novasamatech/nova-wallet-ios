import Foundation
import Operation_iOS
import SubstrateSdk

protocol TokenBalanceMintingFactoryProtocol {
    func createTokenMintingWrapper(
        for accountId: AccountId,
        amount: Balance,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<RuntimeCallCollecting>
}

enum TokenBalanceMintingFactoryError: Error {
    case unsupportedAsset(AssetStorageInfo)
    case unexpectedOnchainData
}

final class TokenBalanceMintingFactory {
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue

    init(chainRegistry: ChainRegistryProtocol, operationQueue: OperationQueue) {
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
    }
}

private extension TokenBalanceMintingFactory {
    private func createNativeTokenMintWrapper(
        accountId: AccountId,
        amount: Balance
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        let collector = RuntimeCallCollector(
            call: BalancesPallet.ForceSetBalance(
                who: .accoundId(accountId),
                newFree: amount
            ).runtimeCall()
        )

        return .createWithResult(collector)
    }

    private func createStatemineTokenMintWrapper(
        accountId: AccountId,
        chain: ChainModel,
        amount: Balance,
        info: AssetsPalletStorageInfo,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        do {
            let connection = try chainRegistry.getConnectionOrError(for: chain.chainId)

            let assetsDetailsPath = StorageCodingPath.assetsDetails(from: info.palletName)
            let requestFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManager(operationQueue: operationQueue)
            )

            let fetchWrapper: CompoundOperationWrapper<[StorageResponse<PalletAssets.DetailsV2>]>
            fetchWrapper = requestFactory.queryItems(
                engine: connection,
                keyParams: { [info.assetId] },
                factory: { codingFactory },
                storagePath: assetsDetailsPath
            )

            let mappingOperation = ClosureOperation<RuntimeCallCollecting> {
                let result = try fetchWrapper.targetOperation.extractNoCancellableResultData()

                guard let details = result.first?.value else {
                    throw TokenBalanceMintingFactoryError.unexpectedOnchainData
                }

                // only issuer can mint tokens in Assets pallet
                let call = try RuntimeCallBuilder(
                    context: codingFactory.createRuntimeJsonContext()
                )
                .addingLast(
                    PalletAssets.MintCall(
                        assetId: info.assetId,
                        beneficiary: .accoundId(accountId),
                        amount: amount
                    ).runtimeCall(for: info.palletName ?? PalletAssets.name)
                )
                .dispatchingAs(.system(.signed(details.issuer)))
                .build()

                return RuntimeCallCollector(call: call)
            }

            mappingOperation.addDependency(fetchWrapper.targetOperation)

            return fetchWrapper.insertingTail(operation: mappingOperation)
        } catch {
            return .createWithError(error)
        }
    }

    private func createOrmlTokenMintWrapper(
        accountId: AccountId,
        amount: Balance,
        info: OrmlTokenStorageInfo
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        let call = OrmlTokensPallet.SetBalanceCall(
            who: .accoundId(accountId),
            currencyId: info.currencyId,
            newFree: amount,
            newReserve: .zero
        ).runtimeCall(for: info.module)

        return .createWithResult(RuntimeCallCollector(call: call))
    }
}

extension TokenBalanceMintingFactory: TokenBalanceMintingFactoryProtocol {
    func createTokenMintingWrapper(
        for accountId: AccountId,
        amount: Balance,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<RuntimeCallCollecting> {
        do {
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainAsset.chain.chainId)
            let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

            let mintWrapper = OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                let assetInfo = try AssetStorageInfo.extract(
                    from: chainAsset.asset,
                    codingFactory: codingFactory
                )

                switch assetInfo {
                case .native:
                    return self.createNativeTokenMintWrapper(accountId: accountId, amount: amount)
                case let .statemine(info):
                    return self.createStatemineTokenMintWrapper(
                        accountId: accountId,
                        chain: chainAsset.chain,
                        amount: amount,
                        info: info,
                        codingFactory: codingFactory
                    )
                case let .orml(info), let .ormlHydrationEvm(info):
                    return self.createOrmlTokenMintWrapper(
                        accountId: accountId,
                        amount: amount,
                        info: info
                    )
                case .erc20, .evmNative, .equilibrium:
                    throw TokenBalanceMintingFactoryError.unsupportedAsset(assetInfo)
                }
            }

            mintWrapper.addDependency(operations: [codingFactoryOperation])

            return mintWrapper.insertingHead(operations: [codingFactoryOperation])
        } catch {
            return .createWithError(error)
        }
    }
}
