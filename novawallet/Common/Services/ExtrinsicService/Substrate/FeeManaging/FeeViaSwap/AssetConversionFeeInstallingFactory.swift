import Foundation
import Operation_iOS

final class AssetConversionFeeInstallingFactory {
    let host: ExtrinsicFeeEstimatorHostProtocol

    private var hydraFeeService: HydraSwapFeeCurrencyService?

    init(host: ExtrinsicFeeEstimatorHostProtocol) {
        self.host = host
    }

    private func setupHydraFeeCurrencyService(for account: ChainAccountResponse) -> HydraSwapFeeCurrencyService {
        let hydraFeeService = AssetConversionFeeSharedStateStore.getOrCreateHydraFeeCurrencyService(
            for: host,
            payerAccountId: account.accountId
        )

        self.hydraFeeService = hydraFeeService

        return hydraFeeService
    }

    private func createHydraFeeInstallingWrapper(
        chainAsset: ChainAsset,
        accountClosure: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        let swapStateWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let account = try accountClosure()

            let feeCurrencyService = self.setupHydraFeeCurrencyService(for: account)

            let swapStateFetchOperation = feeCurrencyService.createFetchOperation()

            return CompoundOperationWrapper(targetOperation: swapStateFetchOperation)
        }

        let mappingOperation = ClosureOperation<ExtrinsicFeeInstalling> {
            let swapState = try swapStateWrapper.targetOperation.extractNoCancellableResultData()

            return HydraExtrinsicFeeInstaller(feeAsset: chainAsset, swapState: swapState)
        }

        mappingOperation.addDependency(swapStateWrapper.targetOperation)

        return swapStateWrapper.insertingTail(operation: mappingOperation)
    }
}

extension AssetConversionFeeInstallingFactory: ExtrinsicCustomFeeInstallingFactoryProtocol {
    func createCustomFeeInstallerWrapper(
        chainAsset: ChainAsset,
        accountClosure: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        switch AssetType(rawType: chainAsset.asset.type) {
        case .statemine where chainAsset.chain.hasAssetHubFees:
            CompoundOperationWrapper.createWithResult(
                ExtrinsicAssetConversionFeeInstaller(
                    feeAsset: chainAsset
                )
            )
        case .orml where chainAsset.chain.hasHydrationFees:
            createHydraFeeInstallingWrapper(
                chainAsset: chainAsset,
                accountClosure: accountClosure
            )
        case .none, .orml, .statemine, .equilibrium, .evmNative, .evmAsset:
            .createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAsset.chainAssetId)
            )
        }
    }
}
