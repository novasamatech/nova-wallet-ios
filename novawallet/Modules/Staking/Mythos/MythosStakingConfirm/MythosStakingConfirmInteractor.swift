import UIKit
import SubstrateSdk

final class MythosStakingConfirmInteractor: MythosStakingBaseInteractor {
    var presenter: MythosStakingConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? MythosStakingConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    private let extrinsicSubmitionMonitor: ExtrinsicSubmitMonitorFactoryProtocol
    private let signer: SigningWrapperProtocol
    private let sharedOperation: SharedOperationProtocol?

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        claimableRewardsService: MythosStakingClaimableRewardsServiceProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        extrinsicSubmitionMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signer: SigningWrapperProtocol,
        sharedOperation: SharedOperationProtocol?,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.extrinsicSubmitionMonitor = extrinsicSubmitionMonitor
        self.signer = signer
        self.sharedOperation = sharedOperation

        super.init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingDetailsService: stakingDetailsService,
            claimableRewardsService: claimableRewardsService,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
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
}

extension MythosStakingConfirmInteractor: MythosStakingConfirmInteractorInputProtocol {
    func submit(model: MythosStakeTransactionModel) {
        let wrapper = extrinsicSubmitionMonitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: getExtrinsicBuilderClosure(from: model),
            signer: signer
        )

        sharedOperation?.markSent()

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            do {
                let model = try result.getSuccessSubmittedModel()
                self?.presenter?.didReceiveSubmissionResult(.success(model))
            } catch {
                self?.sharedOperation?.markComposing()
                self?.presenter?.didReceiveSubmissionResult(.failure(error))
            }
        }
    }
}
