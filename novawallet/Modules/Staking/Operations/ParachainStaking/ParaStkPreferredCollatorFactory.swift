import Foundation
import SubstrateSdk
import Operation_iOS

protocol ParaStkPreferredCollatorFactoryProtocol {
    func createPreferredCollatorWrapper() -> CompoundOperationWrapper<DisplayAddress?>
}

final class ParaStkPreferredCollatorFactory {
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let collatorService: ParachainStakingCollatorServiceProtocol
    let rewardService: ParaStakingRewardCalculatorServiceProtocol
    let preferredCollatorProvider: PreferredValidatorsProviding
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        preferredCollatorProvider: PreferredValidatorsProviding,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.connection = connection
        self.runtimeService = runtimeService
        self.rewardService = rewardService
        self.collatorService = collatorService
        self.identityProxyFactory = identityProxyFactory
        self.preferredCollatorProvider = preferredCollatorProvider
        self.operationQueue = operationQueue
    }

    private func createResultWrapper(
        dependingOn mergeOperation: BaseOperation<AccountId?>
    ) -> CompoundOperationWrapper<DisplayAddress?> {
        OperationCombiningService<DisplayAddress?>.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let optAccountId = try mergeOperation.extractNoCancellableResultData()

            guard let accountId = optAccountId else {
                return CompoundOperationWrapper.createWithResult(nil)
            }

            let identityWrapper = self.identityProxyFactory.createIdentityWrapper(for: { [accountId] })

            let mappingOperation = ClosureOperation<DisplayAddress?> {
                let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
                let address = try accountId.toAddress(using: self.chain.chainFormat)
                let name = identities[address]?.displayName

                return DisplayAddress(address: address, username: name ?? "")
            }

            mappingOperation.addDependency(identityWrapper.targetOperation)

            return CompoundOperationWrapper(
                targetOperation: mappingOperation,
                dependencies: identityWrapper.allOperations
            )
        }
    }
}

extension ParaStkPreferredCollatorFactory: ParaStkPreferredCollatorFactoryProtocol {
    func createPreferredCollatorWrapper() -> CompoundOperationWrapper<DisplayAddress?> {
        let preferredCollatorsWrapper = preferredCollatorProvider.createPreferredValidatorsWrapper(for: chain)

        let collatorsOperation = collatorService.fetchInfoOperation()
        let rewardOperation = rewardService.fetchCalculatorOperation()

        let mergeOperation = ClosureOperation<AccountId?> {
            let collators = try collatorsOperation.extractNoCancellableResultData().collators
            let rewardsCalculator = try rewardOperation.extractNoCancellableResultData()
            let preferredModel = try preferredCollatorsWrapper.targetOperation.extractNoCancellableResultData()

            let preferredCollatorsSet = Set(preferredModel?.preferred ?? [])

            guard !preferredCollatorsSet.isEmpty else {
                return nil
            }

            let optCollator = collators
                .filter { preferredCollatorsSet.contains($0.accountId) }
                .sorted { col1, col2 in
                    let optApr1 = try? rewardsCalculator.calculateAPR(for: col1.accountId)
                    let optApr2 = try? rewardsCalculator.calculateAPR(for: col2.accountId)

                    if let apr1 = optApr1, let apr2 = optApr2 {
                        return apr1 > apr2
                    } else if optApr1 != nil {
                        return true
                    } else {
                        return false
                    }
                }
                .first

            return optCollator?.accountId
        }

        mergeOperation.addDependency(preferredCollatorsWrapper.targetOperation)
        mergeOperation.addDependency(collatorsOperation)
        mergeOperation.addDependency(rewardOperation)

        let resultWrapper = createResultWrapper(dependingOn: mergeOperation)
        resultWrapper.addDependency(operations: [mergeOperation])

        let dependencies = preferredCollatorsWrapper.allOperations +
            [collatorsOperation, rewardOperation, mergeOperation]

        return resultWrapper.insertingHead(operations: dependencies)
    }
}
