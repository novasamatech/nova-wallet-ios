import UIKit
import SoraKeystore
import RobinHood

final class YourValidatorListInteractor: AccountFetching {
    weak var presenter: YourValidatorListInteractorOutputProtocol!

    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol
    let eraValidatorService: EraValidatorServiceProtocol
    let validatorOperationFactory: ValidatorOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    private var stashControllerProvider: StreamableProvider<StashItem>?
    private var nominatorProvider: AnyDataProvider<DecodedNomination>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var rewardDestinationProvider: AnyDataProvider<DecodedPayee>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var activeEra: EraIndex?
    private var stashAddress: AccountAddress?

    init(
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountRepositoryFactory = accountRepositoryFactory
        self.eraValidatorService = eraValidatorService
        self.validatorOperationFactory = validatorOperationFactory
        self.operationManager = operationManager
    }

    func fetchController(for address: AccountAddress) {
        do {
            let accountId = try address.toAccountId()

            fetchFirstMetaAccountResponse(
                for: accountId,
                accountRequest: chainAsset.chain.accountRequest(),
                repositoryFactory: accountRepositoryFactory,
                operationManager: operationManager
            ) { [weak self] result in
                self?.presenter.didReceiveController(result: result)
            }

        } catch {
            presenter.didReceiveController(result: .failure(error))
        }
    }

    func clearAllSubscriptions() {
        activeEra = nil
        clear(dataProvider: &activeEraProvider)

        stashAddress = nil
        clear(streamableProvider: &stashControllerProvider)

        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &rewardDestinationProvider)
    }

    func handle(activeEra: EraIndex?) {
        stashAddress = nil
        clear(streamableProvider: &stashControllerProvider)
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &rewardDestinationProvider)

        self.activeEra = activeEra

        if activeEra != nil, let address = selectedAccount.toAddress() {
            stashControllerProvider = subscribeStashItemProvider(for: address)
        } else {
            presenter.didReceiveController(result: .success(nil))
            presenter.didReceiveValidators(result: .success(nil))
        }
    }

    func handle(stashItem: StashItem?, at _: EraIndex) {
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &rewardDestinationProvider)

        stashAddress = stashItem?.stash

        if
            let stashItem = stashItem,
            let controllerId = try? stashItem.controller.toAccountId(),
            let stashId = try? stashItem.stash.toAccountId() {
            fetchController(for: stashItem.controller)

            nominatorProvider = subscribeNomination(
                for: stashId,
                chainId: chainAsset.chain.chainId
            )

            ledgerProvider = subscribeLedgerInfo(
                for: controllerId,
                chainId: chainAsset.chain.chainId
            )

            rewardDestinationProvider = subscribePayee(for: stashId, chainId: chainAsset.chain.chainId)
        } else {
            presenter.didReceiveController(result: .success(nil))
            presenter.didReceiveValidators(result: .success(nil))
        }
    }

    func handle(nomination: Nomination?, stashAddress: AccountAddress, at activeEra: EraIndex) {
        guard let nomination = nomination else {
            presenter.didReceiveValidators(result: .success(nil))
            return
        }

        let validatorsWrapper = createValidatorsWrapper(
            for: nomination,
            stashAddress: stashAddress,
            activeEra: activeEra
        )

        validatorsWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try validatorsWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceiveValidators(result: .success(result))
                } catch {
                    self?.presenter.didReceiveValidators(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: validatorsWrapper.allOperations, in: .transient)
    }

    func createValidatorsWrapper(
        for nomination: Nomination,
        stashAddress: AccountAddress,
        activeEra: EraIndex
    ) -> CompoundOperationWrapper<YourValidatorsModel> {
        if nomination.submittedIn >= activeEra {
            let activeValidatorsWrapper = validatorOperationFactory.activeValidatorsOperation(
                for: stashAddress
            )

            let selectedValidatorsWrapper = validatorOperationFactory.pendingValidatorsOperation(
                for: nomination.targets
            )

            let mergeOperation = ClosureOperation<YourValidatorsModel> {
                let activeValidators = try activeValidatorsWrapper.targetOperation
                    .extractNoCancellableResultData()
                let selectedValidators = try selectedValidatorsWrapper.targetOperation
                    .extractNoCancellableResultData()

                return YourValidatorsModel(
                    currentValidators: activeValidators,
                    pendingValidators: selectedValidators
                )
            }

            mergeOperation.addDependency(selectedValidatorsWrapper.targetOperation)
            mergeOperation.addDependency(activeValidatorsWrapper.targetOperation)

            let dependencies = selectedValidatorsWrapper.allOperations + activeValidatorsWrapper.allOperations

            return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
        } else {
            let selectedValidatorsWrapper = validatorOperationFactory.allSelectedOperation(
                by: nomination,
                nominatorAddress: stashAddress
            )

            let mapOperation = ClosureOperation<YourValidatorsModel> {
                let curentValidators = try selectedValidatorsWrapper.targetOperation
                    .extractNoCancellableResultData()

                return YourValidatorsModel(
                    currentValidators: curentValidators,
                    pendingValidators: []
                )
            }

            mapOperation.addDependency(selectedValidatorsWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: selectedValidatorsWrapper.allOperations
            )
        }
    }
}

extension YourValidatorListInteractor: YourValidatorListInteractorInputProtocol {
    func setup() {
        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)
    }

    func refresh() {
        clearAllSubscriptions()

        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)
    }
}

extension YourValidatorListInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        presenter.didReceiveStashItem(result: result)

        if let stashItem = try? result.get(), let activeEra = activeEra {
            handle(stashItem: stashItem, at: activeEra)
        }
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(activeEra):
            handle(activeEra: activeEra?.index)
        case let .failure(error):
            presenter.didReceiveValidators(result: .failure(error))
        }
    }

    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveLedger(result: result)
    }

    func handleNomination(
        result: Result<Nomination?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(nomination):
            if let stashAddress = stashAddress, let activeEra = activeEra {
                handle(nomination: nomination, stashAddress: stashAddress, at: activeEra)
            }
        case let .failure(error):
            presenter.didReceiveValidators(result: .failure(error))
        }
    }

    func handlePayee(
        result: Result<RewardDestinationArg?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        presenter.didReceiveRewardDestination(result: result)
    }
}
