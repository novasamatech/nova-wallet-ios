import Foundation
import SubstrateSdk
import Operation_iOS

typealias StateCallRequestParamsClosure = (DynamicScaleEncoding, RuntimeJsonContext) throws -> Void
typealias StateCallRawParamClosure = () throws -> Data

protocol StateCallResultDecoding {
    associatedtype Result

    func decode(data: Data, using codingFactory: RuntimeCoderFactoryProtocol) throws -> Result
}

protocol StateCallStaticResultDecoding {
    associatedtype Result

    func decode(data: Data) throws -> Result
}

struct StateCallResultFromTypeNameDecoder<T: Decodable>: StateCallResultDecoding {
    typealias Result = T

    let typeName: String

    func decode(data: Data, using codingFactory: RuntimeCoderFactoryProtocol) throws -> T {
        let decoder = try codingFactory.createDecoder(from: data)

        return try decoder.read(type: typeName).map(
            to: T.self,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        )
    }
}

struct StateCallResultFromScaleTypeDecoder<T: ScaleCodable>: StateCallResultDecoding, StateCallStaticResultDecoding {
    typealias Result = T

    func decode(data: Data, using codingFactory: RuntimeCoderFactoryProtocol) throws -> T {
        let decoder = try codingFactory.createDecoder(from: data)

        return try decoder.read()
    }

    func decode(data: Data) throws -> T {
        let decoder = try ScaleDecoder(data: data)
        return try T(scaleDecoder: decoder)
    }
}

struct StateCallRawDataDecoder: StateCallResultDecoding, StateCallStaticResultDecoding {
    typealias Result = Data

    func decode(data: Data, using _: RuntimeCoderFactoryProtocol) throws -> Data {
        data
    }

    func decode(data: Data) throws -> Data {
        data
    }
}

protocol StateCallRequestFactoryProtocol {
    func createWrapper<V, Decoder: StateCallResultDecoding>(
        for functionName: String,
        paramsClosure: StateCallRequestParamsClosure?,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine,
        resultDecoder: Decoder,
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<V> where Decoder.Result == V

    func createStaticCodingWrapper<V, D: StateCallStaticResultDecoding>(
        for functionName: String,
        paramsClosure: StateCallRawParamClosure?,
        connection: JSONRPCEngine,
        decoder: D,
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<V> where D.Result == V
}

extension StateCallRequestFactoryProtocol {
    func createWrapper<V: Decodable>(
        for functionName: String,
        paramsClosure: StateCallRequestParamsClosure?,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine,
        queryType: String,
        at blockHash: BlockHash? = nil
    ) -> CompoundOperationWrapper<V> {
        createWrapper(
            for: functionName,
            paramsClosure: paramsClosure,
            codingFactoryClosure: codingFactoryClosure,
            connection: connection,
            resultDecoder: StateCallResultFromTypeNameDecoder(typeName: queryType),
            at: blockHash
        )
    }

    func createWrapper<V: ScaleCodable>(
        for functionName: String,
        paramsClosure: StateCallRequestParamsClosure?,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine,
        at blockHash: BlockHash? = nil
    ) -> CompoundOperationWrapper<V> {
        createWrapper(
            for: functionName,
            paramsClosure: paramsClosure,
            codingFactoryClosure: codingFactoryClosure,
            connection: connection,
            resultDecoder: StateCallResultFromScaleTypeDecoder<V>(),
            at: blockHash
        )
    }

    func createRawDataWrapper(
        for functionName: String,
        paramsClosure: StateCallRequestParamsClosure?,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine,
        at blockHash: BlockHash? = nil
    ) -> CompoundOperationWrapper<Data> {
        createWrapper(
            for: functionName,
            paramsClosure: paramsClosure,
            codingFactoryClosure: codingFactoryClosure,
            connection: connection,
            resultDecoder: StateCallRawDataDecoder(),
            at: blockHash
        )
    }
}

final class StateCallRequestFactory {
    let rpcTimeout: Int

    init(rpcTimeout: Int = JSONRPCTimeout.singleNode) {
        self.rpcTimeout = rpcTimeout
    }
}

extension StateCallRequestFactory: StateCallRequestFactoryProtocol {
    func createWrapper<V, Decoder: StateCallResultDecoding>(
        for functionName: String,
        paramsClosure: StateCallRequestParamsClosure?,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine,
        resultDecoder: Decoder,
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<V> where Decoder.Result == V {
        let requestOperation = ClosureOperation<StateCallRpc.Request> {
            let codingFactory = try codingFactoryClosure()
            let context = codingFactory.createRuntimeJsonContext()

            let encoder = codingFactory.createEncoder()

            // state call always require parameters even if the list is empty
            try paramsClosure?(encoder, context)

            let param = try encoder.encode()

            return StateCallRpc.Request(
                builtInFunction: functionName,
                blockHash: blockHash
            ) { container in
                try container.encode(param.toHex(includePrefix: true))
            }
        }

        let infoOperation = JSONRPCOperation<StateCallRpc.Request, String>(
            engine: connection,
            method: StateCallRpc.method,
            timeout: rpcTimeout
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

            return try resultDecoder.decode(data: resultData, using: coderFactory)
        }

        mapOperation.addDependency(infoOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [requestOperation, infoOperation])
    }

    func createStaticCodingWrapper<V, D: StateCallStaticResultDecoding>(
        for functionName: String,
        paramsClosure: StateCallRawParamClosure?,
        connection: JSONRPCEngine,
        decoder: D,
        at blockHash: BlockHash?
    ) -> CompoundOperationWrapper<V> where D.Result == V {
        let requestOperation = ClosureOperation<StateCallRpc.Request> {
            let param = try paramsClosure?() ?? Data()

            return StateCallRpc.Request(
                builtInFunction: functionName,
                blockHash: blockHash
            ) { container in
                try container.encode(param.toHex(includePrefix: true))
            }
        }

        let infoOperation = JSONRPCOperation<StateCallRpc.Request, String>(
            engine: connection,
            method: StateCallRpc.method,
            timeout: rpcTimeout
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
            let result = try infoOperation.extractNoCancellableResultData()
            let resultData = try Data(hexString: result)

            return try decoder.decode(data: resultData)
        }

        mapOperation.addDependency(infoOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [requestOperation, infoOperation])
    }
}
