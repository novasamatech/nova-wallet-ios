import Operation_iOS
import SubstrateSdk
import UIKit

final class SubtensorClaimRewardsInteractor: SubtensorStakingBaseInteractor {
    var presenter: SubtensorClaimRewardsInteractorOutputProtocol? {
        get {
            basePresenter as? SubtensorClaimRewardsInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryProtocol
    let signer: SigningWrapperProtocol
    let sharedOperation: SharedOperationProtocol?
    let errorMapper: SubtensorStakingErrorMapping

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol,
        rootClaimableService: SubtensorRootClaimableServiceProtocol,
        preflightFactory: SubtensorPreflightFactoryProtocol,
        tradeQuoteFactory: SubtensorTradeQuoteFactoryProtocol,
        operationService: SubtensorStakingOperationServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signer: SigningWrapperProtocol,
        sharedOperation: SharedOperationProtocol?,
        errorMapper: SubtensorStakingErrorMapping = SubtensorStakingErrorMapper(),
        runtimeProvider: RuntimeCodingServiceProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.extrinsicService = extrinsicService
        self.extrinsicSubmitMonitor = extrinsicSubmitMonitor
        self.signer = signer
        self.sharedOperation = sharedOperation
        self.errorMapper = errorMapper

        super.init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            positionsSyncService: positionsSyncService,
            rootClaimableService: rootClaimableService,
            preflightFactory: preflightFactory,
            tradeQuoteFactory: tradeQuoteFactory,
            operationService: operationService,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

private extension SubtensorClaimRewardsInteractor {
    typealias SubmitMonitorCompletion = (
        Result<SubstrateExtrinsicStatus.SuccessExtrinsic, Error>,
        ExtrinsicSubmittedModel?
    ) -> Void

    func submitAndMonitor(
        call: SubtensorStakingCallModel,
        completion: @escaping SubmitMonitorCompletion
    ) {
        let wrapper = extrinsicSubmitMonitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: call.extrinsicBuilderClosure,
            payingIn: nil,
            signer: signer,
            matchingEvents: SubtensorStakingEventMatcher()
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [errorMapper] result in
            switch result {
            case let .success(submission):
                switch submission.status {
                case let .success(successStatus):
                    completion(.success(successStatus), submission.extrinsicSubmittedModel)
                case let .failure(failedStatus):
                    completion(
                        .failure(errorMapper.mapSubmission(error: failedStatus.error)),
                        submission.extrinsicSubmittedModel
                    )
                }
            case let .failure(error):
                completion(.failure(errorMapper.mapSubmission(error: error)), nil)
            }
        }
    }

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
    func estimateClaimFee(for hotkey: AccountId) {
        extrinsicService.estimateFee(
            SubtensorStakingCallModel.claim(hotkey: hotkey).extrinsicBuilderClosure,
            runningIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(fee):
                self?.basePresenter?.didReceiveFee(fee)
            case let .failure(error):
                self?.basePresenter?.didReceiveBaseError(.feeFailed(error))
            }
        }
    }

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
