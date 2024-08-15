import Foundation
import Operation_iOS
import SubstrateSdk

enum ExtrinsicFeeEstimationRegistryError: Error {
    case unexpectedChainAssetId(ChainAssetId)
}

final class ExtrinsicFeeEstimationRegistry {
    let chain: ChainModel
    let operationQueue: OperationQueue

    init(chain: ChainModel, operationQueue: OperationQueue) {
        self.chain = chain
        self.operationQueue = operationQueue
    }

    private func createNativeFeeEstimatingWrapper(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        ExtrinsicNativeFeeEstimator(
            chain: chain,
            operationQueue: operationQueue
        ).createFeeEstimatingWrapper(
            connection: connection,
            runtimeService: runtimeService,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }

    private func createAssetConversionFeeEstimationWrapper(
        chainAsset: ChainAsset,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        ExtrinsicAssetsCustomFeeEstimator(
            chainAsset: chainAsset,
            operationQueue: operationQueue
        ).createFeeEstimatingWrapper(
            connection: connection,
            runtimeService: runtimeService,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }
}

extension ExtrinsicFeeEstimationRegistry: ExtrinsicFeeEstimationRegistring {
    func createFeeEstimatingWrapper(
        payingIn chainAssetId: ChainAssetId?,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        guard let chainAssetId else {
            return createNativeFeeEstimatingWrapper(
                connection: connection,
                runtimeService: runtimeService,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        }

        guard
            chain.chainId == chainAssetId.chainId,
            let asset = chain.asset(for: chainAssetId.assetId)
        else {
            return CompoundOperationWrapper.createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
            )
        }

        switch AssetType(rawType: asset.type) {
        case .none,
             .orml:
            return createNativeFeeEstimatingWrapper(
                connection: connection,
                runtimeService: runtimeService,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .statemine:
            return createAssetConversionFeeEstimationWrapper(
                chainAsset: .init(chain: chain, asset: asset),
                connection: connection,
                runtimeService: runtimeService,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .equilibrium, .evmNative, .evmAsset:
            return .createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
            )
        }
    }

    func createFeeInstallerWrapper(
        payingIn chainAssetId: ChainAssetId?,
        connection _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        guard let chainAssetId else {
            return CompoundOperationWrapper.createWithResult(ExtrinsicNativeFeeInstaller())
        }

        do {
            guard
                chainAssetId.chainId == chain.chainId,
                let asset = chain.asset(for: chainAssetId.assetId)
            else {
                throw ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
            }

            switch AssetType(rawType: asset.type) {
            case .none:
                return CompoundOperationWrapper.createWithResult(ExtrinsicNativeFeeInstaller())
            case .statemine:
                let assetConversionInstaller = ExtrinsicAssetConversionFeeInstaller(
                    feeAsset: ChainAsset(chain: chain, asset: asset)
                )

                return CompoundOperationWrapper.createWithResult(assetConversionInstaller)
            case .orml, .equilibrium, .evmNative, .evmAsset:
                throw ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
            }
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
