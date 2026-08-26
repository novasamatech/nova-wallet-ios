import Operation_iOS
import SubstrateSdk
import UIKit

class SubtensorStakingSubmitInteractor: SubtensorStakingBaseInteractor {
    var submitPresenter: SubtensorStakingSubmitInteractorOutputProtocol? {
        basePresenter as? SubtensorStakingSubmitInteractorOutputProtocol
    }

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
        quoteFactory: SubtensorQuoteOperationFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signer: SigningWrapperProtocol,
        sharedOperation: SharedOperationProtocol?,
        errorMapper: SubtensorStakingErrorMapping = SubtensorStakingErrorMapper(),
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
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
            quoteFactory: quoteFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: logger
        )
    }

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
        ) { [errorMapper = self.errorMapper] result in
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

    func provideOutcome(for submitted: ExtrinsicSubmittedModel, events: [Event]) {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        execute(
            operation: codingFactoryOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            let outcome = (try? result.get()).flatMap { codingFactory in
                SubtensorExecutedOutcomeParser.parseOutcome(
                    from: events,
                    codingFactory: codingFactory
                )
            }

            self?.positionsSyncService.refresh()

            self?.submitPresenter?.didReceiveSubmissionResult(
                .success(SubtensorSubmissionModel(submitted: submitted, outcome: outcome))
            )
        }
    }
}

extension SubtensorStakingSubmitInteractor: SubtensorStakingSubmitInteractorInputProtocol {
    func submit(call: SubtensorStakingCallModel) {
        do {
            try call.ensureSlippageProtected()
        } catch {
            submitPresenter?.didReceiveSubmissionResult(.failure(error))
            return
        }

        sharedOperation?.markSent()

        submitAndMonitor(call: call) { [weak self] result, submitted in
            switch result {
            case let .success(successStatus):
                if let submitted {
                    self?.provideOutcome(for: submitted, events: successStatus.interestedEvents)
                }
            case let .failure(error):
                self?.sharedOperation?.markComposing()
                self?.submitPresenter?.didReceiveSubmissionResult(.failure(error))
            }
        }
    }
}
