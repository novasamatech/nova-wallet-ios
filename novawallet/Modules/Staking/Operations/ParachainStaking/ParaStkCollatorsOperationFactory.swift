import Foundation
import RobinHood
import SubstrateSdk
import BigInt

protocol ParaStkCollatorsOperationFactoryProtocol {
    func electedCollatorsInfoOperation(
        for collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<[CollatorSelectionInfo]>
}

final class ParaStkCollatorsOperationFactory {
    let requestFactory: StorageRequestFactoryProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol

    init(
        requestFactory: StorageRequestFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol
    ) {
        self.requestFactory = requestFactory
        self.identityOperationFactory = identityOperationFactory
    }

    // swiftlint:disable:next function_parameter_count
    private func createMappingOperation(
        dependingOn selectedCollatorsOperation: BaseOperation<SelectedRoundCollators>,
        rewardEngineOperation: BaseOperation<ParaStakingRewardCalculatorEngineProtocol>,
        metadataOperation: BaseOperation<[StorageResponse<ParachainStaking.CandidateMetadata>]>,
        identityOperation: BaseOperation<[AccountAddress: AccountIdentity]>,
        minTechStakeOperation: BaseOperation<BigUInt>,
        chainFormat: ChainFormat
    ) -> BaseOperation<[CollatorSelectionInfo]> {
        ClosureOperation<[CollatorSelectionInfo]> {
            let selectedCollators = try selectedCollatorsOperation.extractNoCancellableResultData()
            let metadataList = try metadataOperation.extractNoCancellableResultData()
            let identities = try identityOperation.extractNoCancellableResultData()
            let rewardEngine = try rewardEngineOperation.extractNoCancellableResultData()
            let minTechStake = try minTechStakeOperation.extractNoCancellableResultData()

            let commission = selectedCollators.commission

            return try zip(selectedCollators.collators, metadataList)
                .compactMap { collator, metadataResult in
                    guard let metadata = metadataResult.value else {
                        return nil
                    }

                    let address = try collator.accountId.toAddress(using: chainFormat)
                    let apr = try rewardEngine.calculateARP(for: collator.accountId)

                    let identity = identities[address]

                    return CollatorSelectionInfo(
                        accountId: collator.accountId,
                        metadata: metadata,
                        snapshot: collator.snapshot,
                        identity: identity,
                        apr: apr,
                        commission: commission,
                        minTechStake: minTechStake
                    )
                }
        }
    }
}

extension ParaStkCollatorsOperationFactory: ParaStkCollatorsOperationFactoryProtocol {
    func electedCollatorsInfoOperation(
        for collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        chainFormat: ChainFormat
    ) -> CompoundOperationWrapper<[CollatorSelectionInfo]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let selectedCollatorsOperation = collatorService.fetchInfoOperation()
        let rewardEngineOperation = rewardService.fetchCalculatorOperation()

        let metadataWrapper: CompoundOperationWrapper<[StorageResponse<ParachainStaking.CandidateMetadata>]>

        metadataWrapper = requestFactory.queryItems(
            engine: connection,
            keyParams: {
                try selectedCollatorsOperation.extractNoCancellableResultData().collators.map {
                    BytesCodable(wrappedValue: $0.accountId)
                }
            }, factory: {
                try codingFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: ParachainStaking.candidateMetadataPath
        )

        metadataWrapper.addDependency(operations: [codingFactoryOperation, selectedCollatorsOperation])

        let identityWrapper = identityOperationFactory.createIdentityWrapper(
            for: {
                try selectedCollatorsOperation.extractNoCancellableResultData().collators.map(\.accountId)
            },
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chainFormat
        )

        identityWrapper.addDependency(operations: [selectedCollatorsOperation])

        let minTechStakeOperation: BaseOperation<BigUInt> = PrimitiveConstantOperation.operation(
            for: ParachainStaking.minDelegatorStk,
            dependingOn: codingFactoryOperation
        )

        minTechStakeOperation.addDependency(codingFactoryOperation)

        let mappingOperation = createMappingOperation(
            dependingOn: selectedCollatorsOperation,
            rewardEngineOperation: rewardEngineOperation,
            metadataOperation: metadataWrapper.targetOperation,
            identityOperation: identityWrapper.targetOperation,
            minTechStakeOperation: minTechStakeOperation,
            chainFormat: chainFormat
        )

        mappingOperation.addDependency(metadataWrapper.targetOperation)
        mappingOperation.addDependency(identityWrapper.targetOperation)

        let baseOperations = [codingFactoryOperation, selectedCollatorsOperation, rewardEngineOperation,
                              minTechStakeOperation]
        let dependencies = baseOperations + metadataWrapper.allOperations + identityWrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: dependencies
        )
    }
}
