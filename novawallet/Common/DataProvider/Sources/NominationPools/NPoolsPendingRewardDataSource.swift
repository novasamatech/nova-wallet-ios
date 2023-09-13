import Foundation
import RobinHood
import SubstrateSdk
import BigInt

final class NPoolsPendingRewardDataSource {
    typealias Model = String

    static var rewardsBuiltIn: String { "NominationPoolsApi_pending_rewards" }

    let accountId: AccountId
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol

    init(
        accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        self.accountId = accountId
        self.connection = connection
        self.runtimeService = runtimeService
    }

    private func createStateCallOperation(
        for accountId: AccountId,
        builtInFunction: String,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<StateCallRpc.Request> {
        ClosureOperation<StateCallRpc.Request> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let context = codingFactory.createRuntimeJsonContext().toRawContext()

            let encoder = codingFactory.createEncoder()

            try encoder.append(
                accountId,
                ofType: GenericType.accountId.name,
                with: context
            )

            let param = try encoder.encode()

            return StateCallRpc.Request(builtInFunction: builtInFunction) { container in
                try container.encode(param.toHex(includePrefix: true))
            }
        }
    }
}

extension NPoolsPendingRewardDataSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<Model?> {
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let requestOperation = createStateCallOperation(
            for: accountId,
            builtInFunction: Self.rewardsBuiltIn,
            dependingOn: codingFactoryOperation
        )

        requestOperation.addDependency(codingFactoryOperation)

        let infoOperation = JSONRPCOperation<StateCallRpc.Request, String>(
            engine: connection,
            method: StateCallRpc.method
        )

        infoOperation.configurationBlock = {
            do {
                infoOperation.parameters = try requestOperation.extractNoCancellableResultData()
            } catch {
                infoOperation.result = .failure(error)
            }
        }

        infoOperation.addDependency(requestOperation)

        let mapOperation = ClosureOperation<Model?> {
            let coderFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let result = try infoOperation.extractNoCancellableResultData()
            let resultData = try Data(hexString: result)
            let decoder = try coderFactory.createDecoder(from: resultData)
            let remoteModel = try decoder.read(type: KnownType.balance.name).map(
                to: StringScaleMapper<BigUInt>.self,
                with: coderFactory.createRuntimeJsonContext().toRawContext()
            )

            return String(remoteModel.value)
        }

        mapOperation.addDependency(infoOperation)

        let dependencies = [codingFactoryOperation, requestOperation, infoOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
