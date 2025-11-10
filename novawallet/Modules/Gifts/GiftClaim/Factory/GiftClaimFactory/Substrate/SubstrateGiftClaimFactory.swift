import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class SubstrateGiftClaimFactory {
    let claimFactory: GiftClaimFactoryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol
    let transferCommandFactory: SubstrateTransferCommandFactory
    let operationQueue: OperationQueue

    init(
        claimFactory: GiftClaimFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol,
        transferCommandFactory: SubstrateTransferCommandFactory,
        operationQueue: OperationQueue
    ) {
        self.claimFactory = claimFactory
        self.signingWrapperFactory = signingWrapperFactory
        self.extrinsicMonitorFactory = extrinsicMonitorFactory
        self.transferCommandFactory = transferCommandFactory
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension SubstrateGiftClaimFactory {
    func createClaimWrapper(
        dependingOn giftWrapper: CompoundOperationWrapper<GiftModel>,
        chainAsset: ChainAsset,
        amount: OnChainTransferAmount<BigUInt>,
        claimingAccountId: AccountId,
        assetStorageInfo: AssetStorageInfo?
    ) -> CompoundOperationWrapper<Void> {
        let extrinsicBuilderClosre: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let (newBuilder, _) = try addingTransferCommand(
                to: builder,
                amount: amount,
                recepient: claimingAccountId,
                assetStorageInfo: assetStorageInfo
            )

            return newBuilder
        }

        let submitAndMonitorWrapper = createSubmitAndMonitorWrapper(
            gift: { try giftWrapper.targetOperation.extractNoCancellableResultData() },
            extrinsicBuilderClosure: extrinsicBuilderClosre,
            chainAssetId: chainAsset.chainAssetId
        )

        let mapOperation = ClosureOperation<Void> {
            let result = submitAndMonitorWrapper.targetOperation.result

            switch result {
            case let .failure(error):
                throw GiftClaimError.giftClaimFailed(
                    claimingAccountId: claimingAccountId,
                    underlyingError: error
                )
            case .none:
                throw GiftClaimError.giftClaimFailed(
                    claimingAccountId: claimingAccountId,
                    underlyingError: nil
                )
            case .success:
                return
            }
        }

        mapOperation.addDependency(submitAndMonitorWrapper.targetOperation)

        return submitAndMonitorWrapper.insertingTail(operation: mapOperation)
    }

    func createSubmitAndMonitorWrapper(
        gift: @escaping () throws -> GiftModel,
        extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure,
        chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<ExtrinsicMonitorSubmission> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let signingData = GiftSigningData(
                gift: try gift(),
                ethereumBased: false,
                cryptoType: .sr25519
            )
            let signingWrapper = self.signingWrapperFactory.createSigningWrapper(giftSigningData: signingData)

            return self.extrinsicMonitorFactory.submitAndMonitorWrapper(
                extrinsicBuilderClosure: extrinsicBuilderClosure,
                payingIn: chainAssetId,
                signer: signingWrapper
            )
        }
    }

    func addingTransferCommand(
        to builder: ExtrinsicBuilderProtocol,
        amount: OnChainTransferAmount<BigUInt>,
        recepient: AccountId,
        assetStorageInfo: AssetStorageInfo?
    ) throws -> (ExtrinsicBuilderProtocol, CallCodingPath?) {
        guard let assetStorageInfo else {
            return (builder, nil)
        }

        return try transferCommandFactory.addingTransferCommand(
            to: builder,
            amount: amount,
            recipient: recepient,
            assetStorageInfo: assetStorageInfo
        )
    }
}

// MARK: - SubstrateGiftClaimFactoryProtocol

extension SubstrateGiftClaimFactory: SubstrateGiftClaimFactoryProtocol {
    func createClaimWrapper(
        giftDescription: ClaimableGiftDescription,
        assetStorageInfo: AssetStorageInfo?
    ) -> CompoundOperationWrapper<Void> {
        let claimWrapperProvider: GiftClaimWrapperProvider = { giftWrapper in
            self.createClaimWrapper(
                dependingOn: giftWrapper,
                chainAsset: giftDescription.chainAsset,
                amount: giftDescription.amount,
                claimingAccountId: giftDescription.claimingAccountId,
                assetStorageInfo: assetStorageInfo
            )
        }

        return claimFactory.claimGift(
            using: giftDescription,
            claimWrapperProvider: claimWrapperProvider
        )
    }
}
