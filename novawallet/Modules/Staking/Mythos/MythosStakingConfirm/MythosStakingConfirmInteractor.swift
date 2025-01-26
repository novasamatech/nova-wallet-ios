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

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        extrinsicSubmitionMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signer: SigningWrapperProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.extrinsicSubmitionMonitor = extrinsicSubmitionMonitor
        self.signer = signer

        super.init(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingDetailsService: stakingDetailsService,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

extension MythosStakingConfirmInteractor: MythosStakingConfirmInteractorInputProtocol {
    func submit(model: MythosStakeModel) {
        let wrapper = extrinsicSubmitionMonitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: getExtrinsicBuilderClosure(from: model),
            signer: signer
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            do {
                let status = try result.getSuccessExtrinsicStatus()

                self?.presenter?.didReceiveSubmition(result: .success(status.extrinsicHash))
            } catch {
                self?.presenter?.didReceiveSubmition(result: .failure(error))
            }
        }
    }
}
