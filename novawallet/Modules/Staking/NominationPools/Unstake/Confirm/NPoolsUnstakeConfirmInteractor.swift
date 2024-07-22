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

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        signingWrapper: SigningWrapperProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
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
        extrinsicService.submit(
            createExtrinsicClosure(for: unstakingPoints, accountId: accountId, needsMigration: needsMigration),
            signer: signingWrapper,
            runningIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceive(submissionResult: result)
        }
    }
}
