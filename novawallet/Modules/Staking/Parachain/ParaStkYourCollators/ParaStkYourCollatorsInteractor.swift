import UIKit
import Operation_iOS
import SubstrateSdk

final class ParaStkYourCollatorsInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: ParaStkYourCollatorsInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let collatorService: ParachainStakingCollatorServiceProtocol
    let rewardService: CollatorStakingRewardCalculatorServiceProtocol
    let collatorsOperationFactory: ParaStkCollatorsOperationFactoryProtocol
    let operationQueue: OperationQueue

    private var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?
    private var schduledRequestsProvider: StreamableProvider<ParachainStaking.MappedScheduledRequest>?
    private var collatorsCall: CancellableCall?

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: CollatorStakingRewardCalculatorServiceProtocol,
        collatorsOperationFactory: ParaStkCollatorsOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.collatorService = collatorService
        self.rewardService = rewardService
        self.collatorsOperationFactory = collatorsOperationFactory
        self.operationQueue = operationQueue
    }

    deinit {
        clear(cancellable: &collatorsCall)
    }

    private func subscribeDelegator() {
        clear(dataProvider: &delegatorProvider)

        delegatorProvider = subscribeToDelegatorState(
            for: chainAsset.chain.chainId,
            accountId: selectedAccount.chainAccount.accountId
        )
    }

    private func subscribeScheduledRequests() {
        clear(streamableProvider: &schduledRequestsProvider)

        schduledRequestsProvider = subscribeToScheduledRequests(
            for: chainAsset.chain.chainId,
            delegatorId: selectedAccount.chainAccount.accountId
        )
    }

    private func provideCollators(for collatorIds: [AccountId]) {
        clear(cancellable: &collatorsCall)

        let wrapper = collatorsOperationFactory.selectedCollatorsInfoOperation(
            for: collatorIds,
            collatorService: collatorService,
            rewardService: rewardService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    guard self?.collatorsCall === wrapper else {
                        return
                    }

                    self?.collatorsCall = nil

                    let collators = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveCollators(result: .success(collators))
                } catch {
                    self?.presenter?.didReceiveCollators(result: .failure(error))
                }
            }
        }

        collatorsCall = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension ParaStkYourCollatorsInteractor: ParaStkYourCollatorsInteractorInputProtocol {
    func setup() {
        subscribeDelegator()
        subscribeScheduledRequests()
    }

    func retry() {
        subscribeDelegator()
        subscribeScheduledRequests()
    }
}

extension ParaStkYourCollatorsInteractor: ParastakingLocalStorageSubscriber, ParastakingLocalStorageHandler {
    func handleParastakingDelegatorState(
        result: Result<ParachainStaking.Delegator?, Error>,
        for _: ChainModel.Id,
        accountId _: AccountId
    ) {
        presenter?.didReceiveDelegator(result: result)

        if let delegator = try? result.get() {
            let collatorIds = delegator.collators()
            provideCollators(for: collatorIds)
        }
    }

    func handleParastakingScheduledRequests(
        result: Result<[ParachainStaking.DelegatorScheduledRequest]?, Error>,
        for _: ChainModel.Id,
        delegatorId _: AccountId
    ) {
        presenter?.didReceiveScheduledRequests(result: result)
    }
}
