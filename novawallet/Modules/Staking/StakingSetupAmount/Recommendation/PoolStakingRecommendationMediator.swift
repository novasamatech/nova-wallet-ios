import Foundation
import BigInt

final class PoolStakingRecommendationMediator: BaseStakingRecommendationMediator {
    let restrictionsBuilder: RelaychainStakingRestrictionsBuilding
    let operationFactory: NominationPoolRecommendationFactoryProtocol
    let operationQueue: OperationQueue

    var restrictions: RelaychainStakingRestrictions?

    init(
        restrictionsBuilder: RelaychainStakingRestrictionsBuilding,
        operationFactory: NominationPoolRecommendationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.restrictionsBuilder = restrictionsBuilder
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }

    private func handle(pool: NominationPools.SelectedPool, amount: BigUInt) {
        guard let restrictions = restrictions else {
            return
        }

        let recommendation = RelaychainStakingRecommendation(
            stakingType: .pool(pool),
            restrictions: restrictions
        )

        didReceive(recommendation: recommendation, for: amount)
    }

    override func updateRecommendation(for amount: BigUInt) {
        if let recommendation = recommendation {
            didReceive(recommendation: recommendation, for: amount)
            return
        }

        let wrapper = operationFactory.createPoolRecommendationWrapper()

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
        restrictionsBuilder.delegate = self
        restrictionsBuilder.start()
    }

    override func clearState() {
        restrictionsBuilder.delegate = nil
        restrictionsBuilder.stop()
    }
}

extension PoolStakingRecommendationMediator: RelaychainStakingRestrictionsBuilderDelegate {
    func restrictionsBuilder(
        _: RelaychainStakingRestrictionsBuilding,
        didPrepare restrictions: RelaychainStakingRestrictions
    ) {
        self.restrictions = restrictions

        isReady = true

        updateRecommendationIfReady()
    }

    func restrictionsBuilder(_: RelaychainStakingRestrictionsBuilding, didReceive error: Error) {
        delegate?.didReceiveRecommendation(error: error)
    }
}
