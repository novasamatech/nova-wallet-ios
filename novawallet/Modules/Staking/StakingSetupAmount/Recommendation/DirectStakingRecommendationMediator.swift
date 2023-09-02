import Foundation
import RobinHood
import SubstrateSdk
import BigInt

class DirectStakingRecommendationMediator: BaseStakingRecommendationMediator {
    let recommendationFactory: DirectStakingRecommendationFactoryProtocol
    let restrictionsBuilder: RelaychainStakingRestrictionsBuilding
    let operationQueue: OperationQueue

    var restrictions: RelaychainStakingRestrictions?

    init(
        recommendationFactory: DirectStakingRecommendationFactoryProtocol,
        restrictionsBuilder: RelaychainStakingRestrictionsBuilding,
        operationQueue: OperationQueue
    ) {
        self.recommendationFactory = recommendationFactory
        self.restrictionsBuilder = restrictionsBuilder
        self.operationQueue = operationQueue
    }

    private func handle(validators: PreparedValidators, amount: BigUInt) {
        guard let restrictions = restrictions else {
            return
        }

        let recommendation = RelaychainStakingRecommendation(
            staking: .direct(validators),
            restrictions: restrictions,
            validationFactory: nil
        )

        didReceive(recommendation: recommendation, for: amount)
    }

    override func updateRecommendation(for amount: BigUInt) {
        if let recommendation = recommendation {
            didReceive(recommendation: recommendation, for: amount)
            return
        }

        let wrapper = recommendationFactory.createValidatorsRecommendationWrapper()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.pendingOperation === wrapper else {
                    return
                }

                self?.pendingOperation = nil

                do {
                    let validators = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.handle(validators: validators, amount: amount)
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

extension DirectStakingRecommendationMediator: RelaychainStakingRestrictionsBuilderDelegate {
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
