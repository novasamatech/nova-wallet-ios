import Foundation
import BigInt
import RobinHood

protocol RelaychainStakingRecommendationMediating: AnyObject {
    var delegate: RelaychainStakingRecommendationDelegate? { get set }

    func startRecommending()
    func update(amount: BigUInt)
    func stopRecommending()
}

protocol RelaychainStakingRecommendationDelegate: AnyObject {
    func didReceive(recommendation: RelaychainStakingRecommendation, amount: BigUInt)
    func didReceiveRecommendation(error: Error)
}

class BaseStakingRecommendationMediator: AnyCancellableCleaning {
    weak var delegate: RelaychainStakingRecommendationDelegate?

    var recommendation: RelaychainStakingRecommendation?
    var amount: BigUInt?
    var pendingOperation: CancellableCall?

    let logger: LoggerProtocol

    var isReady: Bool = false

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    deinit {
        cancelAllOperations()
    }

    func updateRecommendationIfReady() {
        clear(cancellable: &pendingOperation)

        if isReady, let amount = amount {
            updateRecommendation(for: amount)
        }
    }

    func updateRecommendation(for _: BigUInt) {
        fatalError("Must be overriden by subclass")
    }

    func performSetup() {
        fatalError("Must be overriden by subclass")
    }

    func cancelAllOperations() {
        clear(cancellable: &pendingOperation)
    }

    func clearState() {
        cancelAllOperations()

        recommendation = nil
        amount = nil
        isReady = false
    }

    func didReceive(recommendation: RelaychainStakingRecommendation, for amount: BigUInt) {
        self.recommendation = recommendation
        self.amount = amount

        delegate?.didReceive(recommendation: recommendation, amount: amount)
    }
}

extension BaseStakingRecommendationMediator: RelaychainStakingRecommendationMediating {
    func startRecommending() {
        guard !isReady else {
            return
        }

        clearState()

        performSetup()
    }

    func update(amount: BigUInt) {
        guard isReady else {
            self.amount = amount
            return
        }

        clear(cancellable: &pendingOperation)

        self.amount = amount

        updateRecommendation(for: amount)
    }

    func stopRecommending() {
        clearState()
    }
}
