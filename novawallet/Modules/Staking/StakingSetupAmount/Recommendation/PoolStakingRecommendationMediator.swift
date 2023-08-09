import Foundation
import BigInt
import RobinHood

final class PoolStakingRecommendationMediator: BaseStakingRecommendationMediator {
    let restrictionsBuilder: RelaychainStakingRestrictionsBuilding
    let operationFactory: NominationPoolRecommendationFactoryProtocol
    let operationQueue: OperationQueue

    let chainAsset: ChainAsset
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol

    var restrictions: RelaychainStakingRestrictions?

    private var maxMembersPerPoolStorage: UncertainStorage<UInt32?> = .undefined
    private var maxMembersPerPoolProvider: AnyDataProvider<DecodedU32>?

    init(
        chainAsset: ChainAsset,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        restrictionsBuilder: RelaychainStakingRestrictionsBuilding,
        operationFactory: NominationPoolRecommendationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.restrictionsBuilder = restrictionsBuilder
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }

    private func updateReadyState() {
        isReady = restrictions != nil && maxMembersPerPoolStorage.isDefined
    }

    private func handle(pool: NominationPools.SelectedPool, amount: BigUInt) {
        guard let restrictions = restrictions else {
            return
        }

        let recommendation = RelaychainStakingRecommendation(
            staking: .pool(pool),
            restrictions: restrictions,
            validationFactory: nil
        )

        didReceive(recommendation: recommendation, for: amount)
    }

    override func updateRecommendation(for amount: BigUInt) {
        guard case let .defined(maxMembersPerPool) = maxMembersPerPoolStorage else {
            return
        }

        if let recommendation = recommendation {
            didReceive(recommendation: recommendation, for: amount)
            return
        }

        let wrapper = operationFactory.createPoolRecommendationWrapper(for: maxMembersPerPool)

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.pendingOperation === wrapper else {
                    return
                }

                self?.pendingOperation = nil

                do {
                    let pool = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.handle(pool: pool, amount: amount)
                } catch {
                    self?.delegate?.didReceiveRecommendation(error: error)
                }
            }
        }

        pendingOperation = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    override func performSetup() {
        maxMembersPerPoolProvider = subscribeMaxPoolMembersPerPool(for: chainAsset.chain.chainId)

        restrictionsBuilder.delegate = self
        restrictionsBuilder.start()
    }

    override func clearState() {
        maxMembersPerPoolProvider = nil

        restrictionsBuilder.delegate = nil
        restrictionsBuilder.stop()
    }
}

extension PoolStakingRecommendationMediator: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handleMaxPoolMembersPerPool(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(value):
            let shouldUpdate = maxMembersPerPoolStorage
                .map { $0 != value }
                .value ?? true

            maxMembersPerPoolStorage = .defined(value)

            updateReadyState()

            if shouldUpdate {
                updateRecommendationIfReady()
            }
        case let .failure(error):
            delegate?.didReceiveRecommendation(error: error)
        }
    }
}

extension PoolStakingRecommendationMediator: RelaychainStakingRestrictionsBuilderDelegate {
    func restrictionsBuilder(
        _: RelaychainStakingRestrictionsBuilding,
        didPrepare restrictions: RelaychainStakingRestrictions
    ) {
        self.restrictions = restrictions

        updateReadyState()
        updateRecommendationIfReady()
    }

    func restrictionsBuilder(_: RelaychainStakingRestrictionsBuilding, didReceive error: Error) {
        delegate?.didReceiveRecommendation(error: error)
    }
}
