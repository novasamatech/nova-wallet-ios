import Foundation
import SubstrateSdk
import Operation_iOS
import BigInt
import NovaCrypto

final class PayoutRewardsService: PayoutRewardsServiceProtocol {
    let selectedAccountAddress: String
    let chainFormat: ChainFormat
    let validatorsResolutionFactory: PayoutValidatorsFactoryProtocol
    let erasStakersPagedSearchFactory: ExposurePagedEraOperationFactoryProtocol
    let exposureFactoryFacade: StakingValidatorExposureFacadeProtocol
    let unclaimedRewardsFacade: StakingUnclaimedRewardsFacadeProtocol
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let engine: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let payoutInfoFactory: PayoutInfoFactoryProtocol
    let logger: LoggerProtocol?

    init(
        selectedAccountAddress: String,
        chainFormat: ChainFormat,
        validatorsResolutionFactory: PayoutValidatorsFactoryProtocol,
        erasStakersPagedSearchFactory: ExposurePagedEraOperationFactoryProtocol,
        exposureFactoryFacade: StakingValidatorExposureFacadeProtocol,
        unclaimedRewardsFacade: StakingUnclaimedRewardsFacadeProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        payoutInfoFactory: PayoutInfoFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.selectedAccountAddress = selectedAccountAddress
        self.chainFormat = chainFormat
        self.validatorsResolutionFactory = validatorsResolutionFactory
        self.erasStakersPagedSearchFactory = erasStakersPagedSearchFactory
        self.exposureFactoryFacade = exposureFactoryFacade
        self.unclaimedRewardsFacade = unclaimedRewardsFacade
        self.runtimeCodingService = runtimeCodingService
        self.storageRequestFactory = storageRequestFactory
        self.engine = engine
        self.operationManager = operationManager
        self.identityProxyFactory = identityProxyFactory
        self.payoutInfoFactory = payoutInfoFactory
        self.logger = logger
    }

    // swiftlint:disable:next function_body_length
    func fetchPayoutsOperationWrapper() -> CompoundOperationWrapper<Staking.PayoutsInfo> {
        do {
            let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

            let historyRangeWrapper = try createChainHistoryRangeOperationWrapper(
                codingFactoryOperation: codingFactoryOperation
            )

            historyRangeWrapper.allOperations.forEach { $0.addDependency(codingFactoryOperation) }

            let validatorsWrapper = validatorsResolutionFactory.createResolutionOperation(for: selectedAccountAddress) {
                try historyRangeWrapper.targetOperation.extractNoCancellableResultData().eraRange
            }

            validatorsWrapper.addDependency(wrapper: historyRangeWrapper)

            let pagedExposuresSearchWrapper = erasStakersPagedSearchFactory.createWrapper(
                for: { try historyRangeWrapper.targetOperation.extractNoCancellableResultData().eraRange },
                codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() },
                connection: engine
            )

            pagedExposuresSearchWrapper.addDependency(operations: [codingFactoryOperation])
            pagedExposuresSearchWrapper.addDependency(wrapper: historyRangeWrapper)

            let exposuresWrapper = exposureFactoryFacade.createWrapper(
                dependingOn: { try validatorsWrapper.targetOperation.extractNoCancellableResultData() },
                exposurePagedEra: { try pagedExposuresSearchWrapper.targetOperation.extractNoCancellableResultData() },
                codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() },
                connection: engine
            )

            exposuresWrapper.addDependency(wrapper: validatorsWrapper)
            exposuresWrapper.addDependency(wrapper: pagedExposuresSearchWrapper)

            let unclaimedRewardsWrapper = unclaimedRewardsFacade.createWrapper(
                for: { try exposuresWrapper.targetOperation.extractNoCancellableResultData() },
                exposurePagedEra: { try pagedExposuresSearchWrapper.targetOperation.extractNoCancellableResultData() },
                codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() },
                connection: engine
            )

            unclaimedRewardsWrapper.addDependency(wrapper: exposuresWrapper)

            let erasRewardDistributionWrapper = try createErasRewardDistributionOperationWrapper(
                dependingOn: { try unclaimedRewardsWrapper.targetOperation.extractNoCancellableResultData() },
                engine: engine,
                codingFactoryOperation: codingFactoryOperation
            )

            erasRewardDistributionWrapper.addDependency(wrapper: unclaimedRewardsWrapper)

            let prefsByEraWrapper = try createValidatorPrefsWrapper(
                dependingOn: { try unclaimedRewardsWrapper.targetOperation.extractNoCancellableResultData() },
                codingFactoryOperation: codingFactoryOperation
            )

            prefsByEraWrapper.addDependency(wrapper: unclaimedRewardsWrapper)

            let identityWrapper = identityProxyFactory.createIdentityWrapper(
                for: {
                    try unclaimedRewardsWrapper.targetOperation.extractNoCancellableResultData()
                        .map(\.accountId)
                        .distinct()
                }
            )

            identityWrapper.addDependency(wrapper: unclaimedRewardsWrapper)

            let payoutOperation = try calculatePayouts(
                for: payoutInfoFactory,
                eraValidatorsOperation: exposuresWrapper.targetOperation,
                unclaimedRewardsOperation: unclaimedRewardsWrapper.targetOperation,
                prefsOperation: prefsByEraWrapper.targetOperation,
                erasRewardOperation: erasRewardDistributionWrapper.targetOperation,
                historyRangeOperation: historyRangeWrapper.targetOperation,
                identityOperation: identityWrapper.targetOperation
            )

            let helperOperations = [codingFactoryOperation] + historyRangeWrapper.allOperations +
                validatorsWrapper.allOperations + pagedExposuresSearchWrapper.allOperations

            let rewardsAndValidatorOperations = exposuresWrapper.allOperations + unclaimedRewardsWrapper.allOperations +
                erasRewardDistributionWrapper.allOperations + prefsByEraWrapper.allOperations

            let dependencies = helperOperations + rewardsAndValidatorOperations + identityWrapper.allOperations

            dependencies.forEach { payoutOperation.addDependency($0) }

            return CompoundOperationWrapper(targetOperation: payoutOperation, dependencies: dependencies)

        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
