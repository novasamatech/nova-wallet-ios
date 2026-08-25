import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorClaimRewardsInteractor: SubtensorStakingSubmitInteractor {
    var presenter: SubtensorClaimRewardsInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorClaimRewardsInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }
}

private extension SubtensorClaimRewardsInteractor {
    func proceedClaims(
        for hotkeys: [AccountId],
        accumulatedTao: Balance,
        lastSubmitted: ExtrinsicSubmittedModel?,
        codingFactory: RuntimeCoderFactoryProtocol
    ) {
        guard let hotkey = hotkeys.first else {
            positionsSyncService.refresh()

            if let lastSubmitted {
                presenter?.didReceiveSubmissionResult(
                    .success(
                        SubtensorSubmissionModel(
                            submitted: lastSubmitted,
                            outcome: .claimed(tao: accumulatedTao)
                        )
                    )
                )
            }

            return
        }

        submitAndMonitor(call: .claim(hotkey: hotkey)) { [weak self] result, submitted in
            switch result {
            case let .success(successStatus):
                let outcome = SubtensorExecutedOutcomeParser.parseOutcome(
                    from: successStatus.interestedEvents,
                    codingFactory: codingFactory
                )

                let claimedTao: Balance = if case let .claimed(tao) = outcome {
                    tao
                } else {
                    0
                }

                self?.proceedClaims(
                    for: Array(hotkeys.dropFirst()),
                    accumulatedTao: accumulatedTao + claimedTao,
                    lastSubmitted: submitted ?? lastSubmitted,
                    codingFactory: codingFactory
                )
            case let .failure(error):
                self?.sharedOperation?.markComposing()

                self?.positionsSyncService.refresh()

                self?.presenter?.didReceiveSubmissionResult(.failure(error))
            }
        }
    }
}

extension SubtensorClaimRewardsInteractor: SubtensorClaimRewardsInteractorInputProtocol {
    func submitClaims(for hotkeys: [AccountId]) {
        sharedOperation?.markSent()

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        execute(
            operation: codingFactoryOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(codingFactory):
                self?.proceedClaims(
                    for: hotkeys,
                    accumulatedTao: 0,
                    lastSubmitted: nil,
                    codingFactory: codingFactory
                )
            case let .failure(error):
                self?.sharedOperation?.markComposing()

                self?.presenter?.didReceiveSubmissionResult(.failure(error))
            }
        }
    }
}
