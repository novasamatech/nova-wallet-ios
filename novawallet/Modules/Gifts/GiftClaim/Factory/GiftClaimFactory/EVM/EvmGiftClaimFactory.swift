import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class EvmGiftClaimFactory {
    let claimFactory: GiftClaimFactoryProtocol
    let signingWrapperFactory: SigningWrapperFactoryProtocol
    let transactionService: EvmTransactionServiceProtocol
    let transferCommandFactory: EvmTransferCommandFactory

    init(
        claimFactory: GiftClaimFactoryProtocol,
        signingWrapperFactory: SigningWrapperFactoryProtocol,
        transactionService: EvmTransactionServiceProtocol,
        transferCommandFactory: EvmTransferCommandFactory
    ) {
        self.claimFactory = claimFactory
        self.signingWrapperFactory = signingWrapperFactory
        self.transactionService = transactionService
        self.transferCommandFactory = transferCommandFactory
    }
}

// MARK: - Private

private extension EvmGiftClaimFactory {
    func createClaimWrapper(
        dependingOn giftWrapper: CompoundOperationWrapper<GiftModel>,
        amount: OnChainTransferAmount<BigUInt>,
        claimingAccountId: AccountId,
        evmFee: EvmFeeModel,
        transferType: EvmTransferType,
        chain: ChainModel
    ) -> CompoundOperationWrapper<Void> {
        let operation = AsyncClosureOperation { [weak self] completion in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let gift = try giftWrapper.targetOperation.extractNoCancellableResultData()

            let extrinsicClosure: EvmTransactionBuilderClosure = { [weak self] builder in
                guard let self else { throw BaseOperationError.parentOperationCancelled }

                let claimingAccountAddress = try claimingAccountId.toAddress(using: chain.chainFormat)

                let (newBuilder, _) = try transferCommandFactory.addingTransferCommand(
                    to: builder,
                    amount: amount,
                    recipient: claimingAccountAddress,
                    type: transferType
                )

                return newBuilder
            }

            let price = EvmTransactionPrice(
                gasLimit: evmFee.gasLimit,
                gasPrice: evmFee.gasPrice
            )

            let signingData = GiftSigningData(
                gift: gift,
                ethereumBased: true,
                cryptoType: .ethereumEcdsa
            )
            let signingWrapper = signingWrapperFactory.createSigningWrapper(giftSigningData: signingData)

            transactionService.submit(
                extrinsicClosure,
                price: price,
                signer: signingWrapper,
                runningIn: .main,
                completion: { result in
                    switch result {
                    case .success:
                        completion(.success(()))
                    case let .failure(error):
                        completion(
                            .failure(
                                GiftClaimError.giftClaimFailed(
                                    claimingAccountId: claimingAccountId,
                                    underlyingError: error
                                )
                            )
                        )
                    }
                }
            )
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

// MARK: - EvmGiftClaimFactoryProtocol

extension EvmGiftClaimFactory: EvmGiftClaimFactoryProtocol {
    func createClaimWrapper(
        giftDescription: ClaimableGiftDescription,
        evmFee: EvmFeeModel,
        transferType: EvmTransferType
    ) -> CompoundOperationWrapper<Void> {
        guard let claimingAccountId = giftDescription.claimingAccountId else {
            return .createWithError(GiftClaimError.claimingAccountNotFound)
        }

        let claimWrapperProvider: GiftClaimWrapperProvider = { giftWrapper, _ in
            self.createClaimWrapper(
                dependingOn: giftWrapper,
                amount: giftDescription.amount,
                claimingAccountId: claimingAccountId,
                evmFee: evmFee,
                transferType: transferType,
                chain: giftDescription.chainAsset.chain
            )
        }

        return claimFactory.claimGift(
            using: giftDescription,
            claimWrapperProvider: claimWrapperProvider
        )
    }

    func createReclaimWrapper(
        gift: GiftModel,
        claimingAccountId: AccountId,
        evmFee: EvmFeeModel,
        transferType: EvmTransferType
    ) -> CompoundOperationWrapper<Void> {
        let claimWrapperProvider: GiftClaimWrapperProvider = { giftWrapper, chainAsset in
            self.createClaimWrapper(
                dependingOn: giftWrapper,
                amount: .all(value: gift.amount),
                claimingAccountId: claimingAccountId,
                evmFee: evmFee,
                transferType: transferType,
                chain: chainAsset.chain
            )
        }

        return claimFactory.reclaimGift(
            gift,
            claimWrapperProvider: claimWrapperProvider
        )
    }
}
