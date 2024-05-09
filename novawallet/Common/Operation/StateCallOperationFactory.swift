import Foundation
import SubstrateSdk
import Operation_iOS

protocol StateCallRequestFactoryProtocol {
    func createWrapper<V: Decodable>(
        for functionName: String,
        paramsClosure: @escaping (DynamicScaleEncoding, RuntimeJsonContext) throws -> Void,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine,
        queryType: String
    ) -> CompoundOperationWrapper<V>
}

final class StateCallRequestFactory {}

extension StateCallRequestFactory: StateCallRequestFactoryProtocol {
    func createWrapper<V>(
        for functionName: String,
        paramsClosure: @escaping (DynamicScaleEncoding, RuntimeJsonContext) throws -> Void,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine,
        queryType: String
    ) -> CompoundOperationWrapper<V> where V: Decodable {
        let requestOperation = ClosureOperation<StateCallRpc.Request> {
            let codingFactory = try codingFactoryClosure()
            let context = codingFactory.createRuntimeJsonContext()

            let encoder = codingFactory.createEncoder()

            try paramsClosure(encoder, context)

            let param = try encoder.encode()

            return StateCallRpc.Request(builtInFunction: functionName) { container in
                try container.encode(param.toHex(includePrefix: true))
            }
        }

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

        let mapOperation = ClosureOperation<V> {
            let coderFactory = try codingFactoryClosure()
            let result = try infoOperation.extractNoCancellableResultData()
            let resultData = try Data(hexString: result)
            let decoder = try coderFactory.createDecoder(from: resultData)

            return try decoder.read(type: queryType).map(
                to: V.self,
                with: coderFactory.createRuntimeJsonContext().toRawContext()
            )
        }

        mapOperation.addDependency(infoOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [requestOperation, infoOperation])
    }
}
