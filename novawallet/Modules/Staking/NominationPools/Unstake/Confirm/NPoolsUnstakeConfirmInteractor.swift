import UIKit
import SubstrateSdk
import BigInt

final class NPoolsUnstakeConfirmInteractor: NPoolsUnstakeBaseInteractor {
    var presenter: NPoolsUnstakeConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? NPoolsUnstakeConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let signingWrapper: SigningWrapperProtocol
    let extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        signingWrapper: SigningWrapperProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        durationFactory: StakingDurationOperationFactoryProtocol,
        npoolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        unstakeLimitsFactory: NPoolsUnstakeOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.signingWrapper = signingWrapper
        self.extrinsicMonitorFactory = extrinsicMonitorFactory

        super.init(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            npoolsLocalSubscriptionFactory: npoolsLocalSubscriptionFactory,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            connection: connection,
            runtimeService: runtimeService,
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            durationFactory: durationFactory,
            npoolsOperationFactory: npoolsOperationFactory,
            unstakeLimitsFactory: unstakeLimitsFactory,
            eventCenter: eventCenter,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }
}

extension NPoolsUnstakeConfirmInteractor: NPoolsUnstakeConfirmInteractorInputProtocol {
    func submit(unstakingPoints: BigUInt, needsMigration: Bool) {
        let wrapper = extrinsicMonitorFactory.submitAndMonitorWrapper(
            extrinsicBuilderClosure: createExtrinsicClosure(
                for: unstakingPoints,
                accountId: accountId,
                needsMigration: needsMigration
            ),
            signer: signingWrapper
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceive(submissionResult: result.mapToExtrinsicSubmittedResult())
        }
    }
}
