import Foundation
import Operation_iOS
import SubstrateSdk

protocol RuntimeConstantFetching {
    func fetchConstant<T: LosslessStringConvertible & Equatable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        fallbackValue: T?,
        callbackQueue: DispatchQueue,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall

    func fetchCompoundConstant<T: Decodable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        fallbackValue: T?,
        callbackQueue: DispatchQueue,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall

    func fetchConstant<T: LosslessStringConvertible & Equatable>(
        oneOfPaths: [ConstantCodingPath],
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        fallbackValue: T?,
        callbackQueue: DispatchQueue,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall
}

extension RuntimeConstantFetching {
    @discardableResult
    func fetchConstant<T: LosslessStringConvertible & Equatable>(
        oneOfPaths: [ConstantCodingPath],
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        fallbackValue: T?,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        fetchConstant(
            oneOfPaths: oneOfPaths,
            runtimeCodingService: runtimeCodingService,
            operationQueue: operationQueue,
            fallbackValue: fallbackValue,
            callbackQueue: .main,
            closure: closure
        )
    }

    @discardableResult
    func fetchConstant<T: LosslessStringConvertible & Equatable>(
        oneOfPaths: [ConstantCodingPath],
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        fetchConstant(
            oneOfPaths: oneOfPaths,
            runtimeCodingService: runtimeCodingService,
            operationQueue: operationQueue,
            fallbackValue: nil,
            callbackQueue: .main,
            closure: closure
        )
    }

    @discardableResult
    func fetchCompoundConstant<T: Decodable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        fallbackValue: T?,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        fetchCompoundConstant(
            for: path,
            runtimeCodingService: runtimeCodingService,
            operationQueue: operationQueue,
            fallbackValue: fallbackValue,
            callbackQueue: .main,
            closure: closure
        )
    }

    @discardableResult
    func fetchConstant<T: LosslessStringConvertible & Equatable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        fallbackValue: T?,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        fetchConstant(
            for: path,
            runtimeCodingService: runtimeCodingService,
            operationQueue: operationQueue,
            fallbackValue: fallbackValue,
            callbackQueue: .main,
            closure: closure
        )
    }

    @discardableResult
    func fetchConstant<T: LosslessStringConvertible & Equatable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        fetchConstant(
            for: path,
            runtimeCodingService: runtimeCodingService,
            operationQueue: operationQueue,
            fallbackValue: nil,
            callbackQueue: .main,
            closure: closure
        )
    }

    @discardableResult
    func fetchCompoundConstant<T: Decodable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        fetchCompoundConstant(
            for: path,
            runtimeCodingService: runtimeCodingService,
            operationQueue: operationQueue,
            fallbackValue: nil,
            callbackQueue: .main,
            closure: closure
        )
    }

    @discardableResult
    func fetchConstant<T: LosslessStringConvertible & Equatable>(
        oneOfPaths: [ConstantCodingPath],
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        fallbackValue: T?,
        callbackQueue: DispatchQueue,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let constOperation = PrimitiveConstantOperation<T>(
            oneOfPaths: oneOfPaths,
            fallbackValue: fallbackValue
        )

        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        constOperation.addDependency(codingFactoryOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: constOperation,
            dependencies: [codingFactoryOperation]
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: callbackQueue,
            callbackClosure: closure
        )

        return wrapper
    }

    @discardableResult
    func fetchConstant<T: LosslessStringConvertible & Equatable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        fallbackValue: T?,
        callbackQueue: DispatchQueue,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        fetchConstant(
            oneOfPaths: [path],
            runtimeCodingService: runtimeCodingService,
            operationQueue: operationQueue,
            fallbackValue: fallbackValue,
            callbackQueue: callbackQueue,
            closure: closure
        )
    }

    @discardableResult
    func fetchCompoundConstant<T: Decodable>(
        for path: ConstantCodingPath,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        fallbackValue: T?,
        callbackQueue _: DispatchQueue,
        closure: @escaping (Result<T, Error>) -> Void
    ) -> CancellableCall {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let constOperation = StorageConstantOperation<T>(path: path, fallbackValue: fallbackValue)
        constOperation.configurationBlock = {
            do {
                constOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                constOperation.result = .failure(error)
            }
        }

        constOperation.addDependency(codingFactoryOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: constOperation,
            dependencies: [codingFactoryOperation]
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: closure
        )

        return wrapper
    }
}
