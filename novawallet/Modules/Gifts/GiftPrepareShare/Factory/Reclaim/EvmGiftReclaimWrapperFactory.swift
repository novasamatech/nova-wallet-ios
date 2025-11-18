import Foundation
import Operation_iOS

final class EvmGiftReclaimWrapperFactory: GiftReclaimStatusUpdating {
    let chainRegistry: ChainRegistryProtocol
    let giftRepository: AnyDataProviderRepository<GiftModel>
    let walletChecker: GiftReclaimWalletCheckerProtocol
    let claimOperationFactory: EvmGiftClaimFactoryProtocol
    let transactionService: EvmTransactionServiceProtocol
    let transferCommandFactory: EvmTransferCommandFactory
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        giftRepository: AnyDataProviderRepository<GiftModel>,
        walletChecker: GiftReclaimWalletCheckerProtocol,
        claimOperationFactory: EvmGiftClaimFactoryProtocol,
        transactionService: EvmTransactionServiceProtocol,
        transferCommandFactory: EvmTransferCommandFactory,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue
    ) {
        self.chainRegistry = chainRegistry
        self.giftRepository = giftRepository
        self.walletChecker = walletChecker
        self.claimOperationFactory = claimOperationFactory
        self.transactionService = transactionService
        self.transferCommandFactory = transferCommandFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }
}

// MARK: - Private

private extension EvmGiftReclaimWrapperFactory {
    func createBuilderClosure(
        for gift: GiftModel,
        recipientAccountId: AccountId,
        transferType: EvmTransferType,
        chainAsset: ChainAsset
    ) -> EvmTransactionBuilderClosure {
        { [weak self] builder in
            guard let self else { return builder }

            let recipientAccountAddress = try recipientAccountId.toAddress(
                using: chainAsset.chain.chainFormat
            )

            let (newBuilder, _) = try transferCommandFactory.addingTransferCommand(
                to: builder,
                amount: .all(value: gift.amount),
                recipient: recipientAccountAddress,
                type: transferType
            )

            return newBuilder
        }
    }

    func createFeeOperation(
        for gift: GiftModel,
        recipientAccountId: AccountId,
        transferType: EvmTransferType,
        chainAsset: ChainAsset
    ) -> BaseOperation<EvmFeeModel> {
        AsyncClosureOperation { completion in
            let builderClosure = self.createBuilderClosure(
                for: gift,
                recipientAccountId: recipientAccountId,
                transferType: transferType,
                chainAsset: chainAsset
            )

            self.transactionService.estimateFee(
                builderClosure,
                runningIn: self.workingQueue
            ) { result in
                switch result {
                case let .success(fee):
                    completion(.success(fee))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - GiftReclaimWrapperFactoryProtocol

extension EvmGiftReclaimWrapperFactory: GiftReclaimWrapperFactoryProtocol {
    func reclaimGift(
        _ gift: GiftModel,
        selectedWallet: MetaAccountModel
    ) -> CompoundOperationWrapper<Void> {
        do {
            let chain = try chainRegistry.getChainOrError(for: gift.chainAssetId.chainId)
            let chainAsset = try chain.chainAssetOrError(for: gift.chainAssetId.assetId)

            let recipientAccountId = try walletChecker.findGiftRecipientAccount(
                for: chain,
                in: selectedWallet
            )

            let transferType: EvmTransferType = if chainAsset.asset.isEvmNative {
                .native
            } else if let address = chainAsset.asset.evmContractAddress, (try? address.toEthereumAccountId()) != nil {
                .erc20(address)
            } else {
                throw AccountAddressConversionError.invalidEthereumAddress
            }

            let feeOperation = createFeeOperation(
                for: gift,
                recipientAccountId: recipientAccountId,
                transferType: transferType,
                chainAsset: chainAsset
            )

            let reclaimWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let fee = try feeOperation.extractNoCancellableResultData()

                return self.claimOperationFactory.createReclaimWrapper(
                    gift: gift,
                    claimingAccountId: recipientAccountId,
                    evmFee: fee,
                    transferType: transferType
                )
            }

            let statusUpdateOperation = createPersistedStatusUpdateOperation(
                for: gift,
                dependingOn: reclaimWrapper
            )

            reclaimWrapper.addDependency(operations: [feeOperation])
            statusUpdateOperation.addDependency(reclaimWrapper.targetOperation)

            return reclaimWrapper
                .insertingHead(operations: [feeOperation])
                .insertingTail(operation: statusUpdateOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
