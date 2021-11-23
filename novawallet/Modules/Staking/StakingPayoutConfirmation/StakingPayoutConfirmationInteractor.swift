import Foundation
import SoraKeystore
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt

final class StakingPayoutConfirmationInteractor: AccountFetching {
    typealias Batch = [PayoutInfo]

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let signer: SigningWrapperProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?
    let payouts: [PayoutInfo]

    private var batches: [Batch]?

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var stashControllerProvider: StreamableProvider<StashItem>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?

    private var stashItem: StashItem?

    weak var presenter: StakingPayoutConfirmationInteractorOutputProtocol!

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicOperationFactory: ExtrinsicOperationFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        signer: SigningWrapperProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        operationManager: OperationManagerProtocol,
        payouts: [PayoutInfo],
        logger: LoggerProtocol? = nil
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicOperationFactory = extrinsicOperationFactory
        self.extrinsicService = extrinsicService
        self.runtimeService = runtimeService
        self.signer = signer
        self.accountRepositoryFactory = accountRepositoryFactory
        self.operationManager = operationManager
        self.payouts = payouts
        self.logger = logger
    }

    // MARK: - Private functions

    private func createExtrinsicBuilderClosure(for batches: [Batch]) -> ExtrinsicBuilderIndexedClosure? {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderIndexedClosure = { builder, index in
            try batches[index].forEach { payout in
                let payoutCall = try callFactory.payout(
                    validatorId: payout.validator,
                    era: payout.era
                )

                _ = try builder.adding(call: payoutCall)
            }

            return builder
        }

        return closure
    }

    private func createExtrinsicBuilderClosure(for batch: Batch) -> ExtrinsicBuilderClosure? {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderClosure = { builder in
            try batch.forEach { payout in
                let payoutCall = try callFactory.payout(
                    validatorId: payout.validator,
                    era: payout.era
                )

                _ = try builder.adding(call: payoutCall)
            }

            return builder
        }

        return closure
    }

    private func provideRewardAmount() {
        guard let accountItem = try? selectedAccount.toAccountItem() else {
            return
        }

        let rewardAmount = payouts.map(\.reward).reduce(0, +)

        presenter.didRecieve(account: accountItem, rewardAmount: rewardAmount)
    }

    private func provideRewardDestination(with payee: RewardDestinationArg) {
        guard let stashItem = stashItem else {
            presenter.didReceiveRewardDestination(result: .failure(CommonError.undefined))
            return
        }

        do {
            let rewardDestination = try RewardDestination(
                payee: payee,
                stashItem: stashItem,
                chainFormat: chainAsset.chain.chainFormat
            )

            switch rewardDestination {
            case .restake:
                presenter.didReceiveRewardDestination(result: .success(.restake))

            case let .payout(payoutAddress):
                let payoutId = try payoutAddress.toAccountId()

                fetchFirstAccount(
                    for: payoutId,
                    accountRequest: chainAsset.chain.accountRequest(),
                    repositoryFactory: accountRepositoryFactory,
                    operationManager: operationManager
                ) { [weak self] result in
                    switch result {
                    case let .success(accountItem):
                        let displayAddress = DisplayAddress(
                            address: payoutAddress,
                            username: accountItem?.username ?? ""
                        )

                        let result: RewardDestination = .payout(account: displayAddress)

                        self?.presenter.didReceiveRewardDestination(result: .success(result))
                    case let .failure(error):
                        self?.presenter.didReceiveRewardDestination(result: .failure(error))
                    }
                }
            }
        } catch {
            presenter.didReceiveRewardDestination(result: .failure(error))
            logger?.error("Did receive reward destination error: \(error)")
        }
    }

    private func createFeeOperationWrapper() -> CompoundOperationWrapper<Decimal>? {
        guard let batches = batches, !batches.isEmpty else { return nil }

        let feeBatches = batches.count > 1 ?
            [batches[0], batches[batches.count - 1]] :
            [batches[0]]

        guard let feeClosure = createExtrinsicBuilderClosure(for: feeBatches) else { return nil }

        let feeOperation = extrinsicOperationFactory.estimateFeeOperation(
            feeClosure,
            numberOfExtrinsics: feeBatches.count
        )

        let dependencies = feeOperation.allOperations
        let precision = chainAsset.assetDisplayInfo.assetPrecision

        let mergeOperation = ClosureOperation<Decimal> {
            let results = try feeOperation.targetOperation.extractNoCancellableResultData()

            let fees: [Decimal] = try results.map { result in
                let dispatchInfo = try result.get()
                return BigUInt(dispatchInfo.fee).map {
                    Decimal.fromSubstrateAmount($0, precision: precision) ?? 0.0
                } ?? 0.0
            }

            return (fees.first ?? 0.0) * Decimal(batches.count - 1) + (fees.last ?? 0.0)
        }

        mergeOperation.addDependency(feeOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: dependencies
        )
    }

    private func createBatchesOperationWrapper(
        from payouts: [PayoutInfo]
    ) -> CompoundOperationWrapper<[Batch]>? {
        guard let firstPayout = payouts.first,
              let feeClosure = createExtrinsicBuilderClosure(for: [firstPayout])
        else { return nil }

        let blockWeightsWrapper = createBlockWeightsWrapper()
        let feeWrapper = extrinsicOperationFactory.estimateFeeOperation(feeClosure)

        let batchesOperationWrapper = ClosureOperation<[Batch]> {
            let blockWeights = try blockWeightsWrapper.targetOperation.extractNoCancellableResultData()
            let fee = try feeWrapper.targetOperation.extractNoCancellableResultData()

            let batchSize = Int(Double(blockWeights.maxBlock) / Double(fee.weight) * 0.64)
            let batches = stride(from: 0, to: payouts.count, by: batchSize).map {
                Array(payouts[$0 ..< Swift.min($0 + batchSize, payouts.count)])
            }

            return batches
        }

        batchesOperationWrapper.addDependency(blockWeightsWrapper.targetOperation)
        batchesOperationWrapper.addDependency(feeWrapper.targetOperation)

        let dependencies = blockWeightsWrapper.allOperations + feeWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: batchesOperationWrapper,
            dependencies: dependencies
        )
    }

    private func createBlockWeightsWrapper() -> CompoundOperationWrapper<BlockWeights> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let blockWeightsOperation = StorageConstantOperation<BlockWeights>(path: .blockWeights)
        blockWeightsOperation.configurationBlock = {
            do {
                blockWeightsOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                blockWeightsOperation.result = .failure(error)
            }
        }

        blockWeightsOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(
            targetOperation: blockWeightsOperation,
            dependencies: [codingFactoryOperation]
        )
    }

    private func generateBatches(completion closure: @escaping () -> Void) {
        guard let batchesOperation = createBatchesOperationWrapper(from: payouts) else {
            return
        }

        batchesOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    self?.batches = try batchesOperation.targetOperation.extractNoCancellableResultData()
                    closure()
                } catch {
                    self?.presenter.didReceiveFee(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: batchesOperation.allOperations, in: .transient)
    }
}

// MARK: - StakingPayoutConfirmationInteractorInputProtocol

extension StakingPayoutConfirmationInteractor: StakingPayoutConfirmationInteractorInputProtocol {
    func setup() {
        generateBatches { self.estimateFee() }

        if let accountAddress = selectedAccount.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: accountAddress)
        } else {
            presenter.didReceiveRewardDestination(result: .failure(ChainAccountFetchingError.accountNotExists))
        }

        balanceProvider = subscribeToAccountInfoProvider(
            for: selectedAccount.accountId,
            chainId: chainAsset.chain.chainId
        )

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }

        provideRewardAmount()
    }

    func submitPayout() {
        guard let batches = batches, !batches.isEmpty else { return }

        presenter.didStartPayout()

        guard let closure = createExtrinsicBuilderClosure(for: batches) else { return }

        extrinsicService.submit(
            closure,
            signer: signer,
            runningIn: .main,
            numberOfExtrinsics: batches.count
        ) { [weak self] result in
            do {
                let txHashes: [String] = try result.map { result in
                    try result.get()
                }

                self?.presenter.didCompletePayout(txHashes: txHashes)
            } catch {
                self?.presenter.didFailPayout(error: error)
            }
        }
    }

    func estimateFee() {
        guard let feeOperation = createFeeOperationWrapper() else {
            presenter.didReceiveFee(result: .failure(CommonError.undefined))
            return
        }

        feeOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let fee = try feeOperation.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceiveFee(result: .success(fee))
                } catch {
                    self?.presenter.didReceiveFee(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: feeOperation.allOperations, in: .transient)
    }
}

extension StakingPayoutConfirmationInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handlePayee(result: Result<RewardDestinationArg?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        switch result {
        case let .success(payee):
            guard let payee = payee else {
                return
            }

            provideRewardDestination(with: payee)

        case let .failure(error):
            presenter.didReceiveRewardDestination(result: .failure(error))
        }
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            clear(dataProvider: &payeeProvider)

            stashItem = try result.get()

            let maybeStashId = try stashItem?.stash.toAccountId()

            if let stashId = maybeStashId {
                payeeProvider = subscribePayee(for: stashId, chainId: chainAsset.chain.chainId)
            } else {
                presenter.didReceiveRewardDestination(result: .success(nil))
            }
        } catch {
            presenter.didReceiveRewardDestination(result: .failure(error))
            logger?.error("Stash subscription item error: \(error)")
        }
    }
}

extension StakingPayoutConfirmationInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingPayoutConfirmationInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}
