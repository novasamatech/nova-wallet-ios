import UIKit
import SubstrateSdk

final class MythosStkUnstakeConfirmInteractor: MythosStkUnstakeInteractor {
    var presenter: MythosStkUnstakeConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? MythosStkUnstakeConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let submissionFactory: ExtrinsicSubmitMonitorFactoryProtocol
    let signer: SigningWrapperProtocol

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        claimableRewardsService: MythosStakingClaimableRewardsServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        submissionFactory: ExtrinsicSubmitMonitorFactoryProtocol,
        signer: SigningWrapperProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        stakingDurationFactory: MythosStkDurationOperationFactoryProtocol,
        blocktimeEstimationService: BlockTimeEstimationServiceProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.submissionFactory = submissionFactory
        self.signer = signer

        super.init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingDetailsService: stakingDetailsService,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            claimableRewardsService: claimableRewardsService,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            stakingDurationFactory: stakingDurationFactory,
            blocktimeEstimationService: blocktimeEstimationService,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

extension MythosStkUnstakeConfirmInteractor: MythosStkUnstakeConfirmInteractorInputProtocol {
    func submit(model: MythosStkUnstakeModel) {
        let builderClosure = getExtrinsicBuilderClosure(for: model)

        let wrapper = submissionFactory.submitAndMonitorWrapper(
            extrinsicBuilderClosure: builderClosure,
            signer: signer
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            do {
                let model = try result.getSuccessSubmittedModel()
                self?.presenter?.didReceiveSubmissionResult(.success(model))
            } catch {
                self?.presenter?.didReceiveSubmissionResult(.failure(error))
            }
        }
    }
}
