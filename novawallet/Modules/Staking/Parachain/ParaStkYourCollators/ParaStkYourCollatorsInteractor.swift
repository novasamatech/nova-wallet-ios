import UIKit
import RobinHood
import SubstrateSdk

final class ParaStkYourCollatorsInteractor: AnyProviderAutoCleaning {
    weak var presenter: ParaStkYourCollatorsInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let collatorService: ParachainStakingCollatorServiceProtocol
    let rewardService: ParaStakingRewardCalculatorServiceProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let collatorsOperationFactory: ParaStkCollatorsOperationFactoryProtocol
    let operationQueue: OperationQueue

    private var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?
    private var collatorsCall: CancellableCall?

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        collatorsOperationFactory: ParaStkCollatorsOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.collatorService = collatorService
        self.rewardService = rewardService
        self.collatorsOperationFactory = collatorsOperationFactory
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
    }

    deinit {
        cancelCollatorsRequest()
    }

    private func subscribeDelegator() {
        clear(dataProvider: &delegatorProvider)

        delegatorProvider = subscribeToDelegatorState(
            for: chainAsset.chain.chainId,
            accountId: selectedAccount.chainAccount.accountId
        )
    }

    private func cancelCollatorsRequest() {
        let call = collatorsCall
        collatorsCall = nil
        call?.cancel()
    }

    private func provideCollators(for collatorIds: [AccountId]) {
        cancelCollatorsRequest()

        let wrapper = collatorsOperationFactory.selectedCollatorsInfoOperation(
            for: collatorIds,
            collatorService: collatorService,
            rewardService: rewardService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            chainFormat: chainAsset.chain.chainFormat
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
    }

    func retry() {
        subscribeDelegator()
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
}
