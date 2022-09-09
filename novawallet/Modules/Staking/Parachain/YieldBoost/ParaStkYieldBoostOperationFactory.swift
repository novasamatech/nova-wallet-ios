import Foundation
import BigInt
import RobinHood
import SubstrateSdk

protocol ParaStkYieldBoostOperationFactoryProtocol {
    func createAutocompoundParamsOperation(
        for connection: JSONRPCEngine,
        request: ParaStkYieldBoostRequest
    ) -> CompoundOperationWrapper<ParaStkYieldBoostResponse>

    func createAutocompoundFeeOperation(for connection: JSONRPCEngine) -> CompoundOperationWrapper<BigUInt>

    func createExecutionTimeOperation(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        requestFactory: StorageRequestFactoryProtocol,
        periodInDays: Int
    ) -> CompoundOperationWrapper<AutomationTime.Seconds>
}

final class ParaStkYieldBoostOperationFactory: ParaStkYieldBoostOperationFactoryProtocol {
    enum RPCMethods {
        static let calculateOptimalAutostaking = "automationTime_calculateOptimalAutostaking"
        static let calculateFee = "automationTime_getTimeAutomationFees"
    }

    func createAutocompoundParamsOperation(
        for connection: JSONRPCEngine,
        request: ParaStkYieldBoostRequest
    ) -> CompoundOperationWrapper<ParaStkYieldBoostResponse> {
        let operation: JSONRPCOperation<ParaStkYieldBoostRequest, ParaStkYieldBoostResponse> = JSONRPCOperation(
            engine: connection,
            method: RPCMethods.calculateOptimalAutostaking,
            parameters: request
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createAutocompoundFeeOperation(for connection: JSONRPCEngine) -> CompoundOperationWrapper<BigUInt> {
        let request = ParaStkYieldBoostFeeRequest(
            action: .autoCompoundDelegatedStake,
            executions: 1
        )

        let feeFetchOperation: JSONRPCOperation<ParaStkYieldBoostFeeRequest, Decimal> = JSONRPCOperation(
            engine: connection,
            method: RPCMethods.calculateFee,
            parameters: request
        )

        let mapOperation = ClosureOperation<BigUInt> {
            let feeDecimal = try feeFetchOperation.extractNoCancellableResultData()

            guard let result = BigUInt((feeDecimal as NSDecimalNumber).stringValue) else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return result
        }

        mapOperation.addDependency(feeFetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [feeFetchOperation])
    }

    func createExecutionTimeOperation(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        requestFactory: StorageRequestFactoryProtocol,
        periodInDays: Int
    ) -> CompoundOperationWrapper<AutomationTime.Seconds> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let timestampWrapper: CompoundOperationWrapper<StorageResponse<StringScaleMapper<BlockTime>>> =
            requestFactory.queryItem(
                engine: connection,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: .timestampNow
            )

        timestampWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<AutomationTime.Seconds> {
            let response = try timestampWrapper.targetOperation.extractNoCancellableResultData().value

            guard let timeInMilliseconds = response?.value else {
                throw BaseOperationError.unexpectedDependentResult
            }

            let seconds = timeInMilliseconds.timeInterval + TimeInterval(periodInDays).secondsFromDays

            return AutomationTime.Seconds(seconds.roundingUpToHour())
        }

        mapOperation.addDependency(timestampWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + timestampWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
