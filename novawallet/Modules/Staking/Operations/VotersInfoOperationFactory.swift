import Foundation
import SubstrateSdk
import RobinHood
import BigInt

protocol VotersInfoOperationFactoryProtocol {
    func createVotersInfoWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<VotersStakingInfo?>
}

final class VotersInfoOperationFactory {
    let operationManager: OperationManagerProtocol

    init(operationManager: OperationManagerProtocol) {
        self.operationManager = operationManager
    }

    private func createBagsListResolutionOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<String?> {
        ClosureOperation<String?> {
            let metadata = try codingFactoryOperation.extractNoCancellableResultData().metadata

            return BagList.possibleModuleNames.first { metadata.getModuleIndex($0) != nil }
        }
    }

    private func createBagsThresholdsOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        bagsModuleOperation: BaseOperation<String?>
    ) -> CompoundOperationWrapper<[BigUInt]?> {
        OperationCombiningService.compoundWrapper(operationManager: operationManager) {
            guard let moduleName = try bagsModuleOperation.extractNoCancellableResultData() else {
                return nil
            }

            let thresholdsOperation: StorageConstantOperation<[StringScaleMapper<BigUInt>]> = StorageConstantOperation(
                path: BagList.bagThresholdsPath(for: moduleName)
            )

            thresholdsOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let mappingOperation = ClosureOperation<[BigUInt]> {
                try thresholdsOperation.extractNoCancellableResultData().map(\.value)
            }

            mappingOperation.addDependency(thresholdsOperation)

            return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [thresholdsOperation])
        }
    }

    private func createMaxElectingVotersOperation(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<UInt32> {
        let valueOperation = PrimitiveConstantOperation<UInt32>(
            path: ElectionProviderMultiPhase.maxElectingVoters,
            fallbackValue: UInt32.max
        )

        valueOperation.configurationBlock = {
            do {
                valueOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                valueOperation.result = .failure(error)
            }
        }

        return valueOperation
    }
}

extension VotersInfoOperationFactory: VotersInfoOperationFactoryProtocol {
    func createVotersInfoWrapper(
        for runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<VotersStakingInfo?> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let moduleResolutionOperation = createBagsListResolutionOperation(dependingOn: codingFactoryOperation)
        let bagsThresholdsWrapper = createBagsThresholdsOperation(
            dependingOn: codingFactoryOperation,
            bagsModuleOperation: moduleResolutionOperation
        )

        let maxElectingVotersOperation = createMaxElectingVotersOperation(dependingOn: codingFactoryOperation)

        let mappingOperation = ClosureOperation<VotersStakingInfo?> {
            guard let bagsThresholds = try bagsThresholdsWrapper.targetOperation.extractNoCancellableResultData() else {
                return nil
            }

            let maxVoters = try maxElectingVotersOperation.extractNoCancellableResultData()

            return .init(bagsThresholds: bagsThresholds, maxElectingVoters: maxVoters)
        }

        moduleResolutionOperation.addDependency(codingFactoryOperation)
        bagsThresholdsWrapper.addDependency(operations: [moduleResolutionOperation])
        maxElectingVotersOperation.addDependency(codingFactoryOperation)

        let dependencies = [codingFactoryOperation, moduleResolutionOperation] + bagsThresholdsWrapper.allOperations +
            [maxElectingVotersOperation]

        dependencies.forEach { mappingOperation.addDependency($0) }

        return .init(targetOperation: mappingOperation, dependencies: dependencies)
    }
}
