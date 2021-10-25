import Foundation
import RobinHood
import SoraKeystore

final class ChangeTargetsConfirmInteractor: SelectValidatorsConfirmInteractorBase, AccountFetching {
    let nomination: PreparedNomination<ExistingBonding>
    let accountRepositoryFactory: AccountRepositoryFactoryProtocol

    init?(
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        durationOperationFactory: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        signer: SigningWrapperProtocol,
        accountRepositoryFactory: AccountRepositoryFactoryProtocol,
        nomination: PreparedNomination<ExistingBonding>
    ) {
        guard let balanceAccountAddress = nomination.bonding.controllerAccount.chainAccount.toAddress() else {
            return nil
        }

        self.nomination = nomination
        self.accountRepositoryFactory = accountRepositoryFactory

        super.init(
            balanceAccountAddress: balanceAccountAddress,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: durationOperationFactory,
            operationManager: operationManager,
            signer: signer
        )
    }

    private func createRewardDestinationOperation(
        for payoutAddress: String
    ) -> CompoundOperationWrapper<RewardDestination<DisplayAddress>> {
        do {
            let accountId = try payoutAddress.toAccountId()
            let repository = accountRepositoryFactory.createMetaAccountRepository(
                for: NSPredicate.filterMetaAccountByAccountId(accountId),
                sortDescriptors: [NSSortDescriptor.accountsByOrder]
            )

            let accountFetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

            let accountRequest = chainAsset.chain.accountRequest()

            let mapOperation: BaseOperation<RewardDestination<DisplayAddress>> = ClosureOperation {
                let metaAccounts = try accountFetchOperation.extractNoCancellableResultData()

                if
                    let accountResponse = metaAccounts.first?.fetch(for: accountRequest) {
                    let displayAddress = DisplayAddress(
                        address: payoutAddress,
                        username: accountResponse.name
                    )

                    return RewardDestination.payout(account: displayAddress)
                } else {
                    let displayAddress = DisplayAddress(
                        address: payoutAddress,
                        username: payoutAddress
                    )

                    return RewardDestination.payout(account: displayAddress)
                }
            }

            mapOperation.addDependency(accountFetchOperation)

            return CompoundOperationWrapper(
                targetOperation: mapOperation,
                dependencies: [accountFetchOperation]
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    private func provideConfirmationModel() {
        let rewardDestWrapper: CompoundOperationWrapper<RewardDestination<DisplayAddress>> = {
            switch nomination.bonding.rewardDestination {
            case .restake:
                return CompoundOperationWrapper.createWithResult(RewardDestination<DisplayAddress>.restake)
            case let .payout(address):
                return createRewardDestinationOperation(for: address)
            }
        }()

        let currentNomination = nomination
        let controllerAddress = balanceAccountAddress

        let mapOperation: BaseOperation<SelectValidatorsConfirmationModel> = ClosureOperation {
            let controller = currentNomination.bonding.controllerAccount
            let rewardDestination = try rewardDestWrapper.targetOperation.extractNoCancellableResultData()

            let controllerDisplayAddress = DisplayAddress(
                address: controllerAddress,
                username: controller.chainAccount.name
            )

            return SelectValidatorsConfirmationModel(
                wallet: controllerDisplayAddress,
                amount: currentNomination.bonding.amount,
                rewardDestination: rewardDestination,
                targets: currentNomination.targets,
                maxTargets: currentNomination.maxTargets,
                hasExistingBond: true,
                hasExistingNomination: currentNomination.bonding.selectedTargets != nil
            )
        }

        let dependencies = rewardDestWrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        mapOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let confirmationModel = try mapOperation.extractNoCancellableResultData()
                    self.presenter.didReceiveModel(result: .success(confirmationModel))
                } catch {
                    self.presenter.didReceiveModel(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: dependencies + [mapOperation], in: .transient)
    }

    private func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure? {
        let targets = nomination.targets

        let closure: ExtrinsicBuilderClosure = { builder in
            let callFactory = SubstrateCallFactory()

            let nominateCall = try callFactory.nominate(targets: targets)

            return try builder
                .adding(call: nominateCall)
        }

        return closure
    }

    override func setup() {
        provideConfirmationModel()

        super.setup()
    }

    override func estimateFee() {
        guard let closure = createExtrinsicBuilderClosure() else {
            return
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter.didReceive(paymentInfo: info)
            case let .failure(error):
                self?.presenter.didReceive(feeError: error)
            }
        }
    }

    override func submitNomination() {
        guard !nomination.targets.isEmpty else {
            presenter.didFailNomination(error: SelectValidatorsConfirmError.extrinsicFailed)
            return
        }

        guard let closure = createExtrinsicBuilderClosure() else {
            return
        }

        presenter.didStartNomination()

        extrinsicService.submit(
            closure,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(txHash):
                self?.presenter.didCompleteNomination(txHash: txHash)
            case let .failure(error):
                self?.presenter.didFailNomination(error: error)
            }
        }
    }
}
