import UIKit
import SubstrateSdk
import Operation_iOS

final class MythosStkUnstakeSetupInteractor: MythosStkUnstakeInteractor {
    var presenter: MythosStkUnstakeSetupInteractorOutputProtocol? {
        get {
            basePresenter as? MythosStkUnstakeSetupInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let identitySyncService: MythosStakingIdentitiesSyncServiceProtocol

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        claimableRewardsService: MythosStakingClaimableRewardsServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        stakingDurationFactory: MythosStkDurationOperationFactoryProtocol,
        blocktimeEstimationService: BlockTimeEstimationServiceProtocol,
        identitySyncService: MythosStakingIdentitiesSyncServiceProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.identitySyncService = identitySyncService

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

    override func onSetup() {
        super.onSetup()

        makeIdentitiesSubscription()
    }
}

private extension MythosStkUnstakeSetupInteractor {
    func makeIdentitiesSubscription() {
        identitySyncService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveDelegationIdentities(newState)
        }
    }
}

extension MythosStkUnstakeSetupInteractor: MythosStkUnstakeSetupInteractorInputProtocol {}
