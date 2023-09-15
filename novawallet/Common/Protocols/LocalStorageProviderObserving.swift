import Foundation
import RobinHood

protocol LocalStorageProviderObserving where Self: AnyObject {
    func addDataProviderObserver<T: Decodable>(
        for provider: AnyDataProvider<ChainStorageDecodedItem<T>>,
        updateClosure: @escaping (T?) -> Void,
        failureClosure: @escaping (Error) -> Void,
        callbackQueue: DispatchQueue,
        options: DataProviderObserverOptions
    )

    func addSingleValueProviderObserver<T: Codable & Equatable>(
        for provider: AnySingleValueProvider<T>,
        updateClosure: @escaping (T?) -> Void,
        failureClosure: @escaping (Error) -> Void,
        callbackQueue: DispatchQueue,
        options: DataProviderObserverOptions
    )

    func addStreamableProviderObserver<T: Identifiable>(
        for provider: StreamableProvider<T>,
        updateClosure: @escaping ([DataProviderChange<T>]) -> Void,
        failureClosure: @escaping (Error) -> Void,
        callbackQueue: DispatchQueue,
        options: StreamableProviderObserverOptions
    )
}

extension LocalStorageProviderObserving {
    func addDataProviderObserver<T: Decodable>(
        for provider: AnyDataProvider<ChainStorageDecodedItem<T>>,
        updateClosure: @escaping (T?) -> Void,
        failureClosure: @escaping (Error) -> Void,
        options: DataProviderObserverOptions = .init(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)
    ) {
        addDataProviderObserver(
            for: provider,
            updateClosure: updateClosure,
            failureClosure: failureClosure,
            callbackQueue: .main,
            options: options
        )
    }

    func addDataProviderObserver<T: Decodable>(
        for provider: AnyDataProvider<ChainStorageDecodedItem<T>>,
        updateClosure: @escaping (T?) -> Void,
        failureClosure: @escaping (Error) -> Void,
        callbackQueue: DispatchQueue,
        options: DataProviderObserverOptions
    ) {
        let update = { (changes: [DataProviderChange<ChainStorageDecodedItem<T>>]) in
            let value = changes.reduceToLastChange()
            updateClosure(value?.item)
        }

        let failure = { error in
            failureClosure(error)
        }

        provider.addObserver(
            self,
            deliverOn: callbackQueue,
            executing: update,
            failing: failure,
            options: options
        )
    }

    func addSingleValueProviderObserver<T: Codable & Equatable>(
        for provider: AnySingleValueProvider<T>,
        updateClosure: @escaping (T?) -> Void,
        failureClosure: @escaping (Error) -> Void,
        options: DataProviderObserverOptions = .init(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)
    ) {
        addSingleValueProviderObserver(
            for: provider,
            updateClosure: updateClosure,
            failureClosure: failureClosure,
            callbackQueue: .main,
            options: options
        )
    }

    func addSingleValueProviderObserver<T: Codable & Equatable>(
        for provider: AnySingleValueProvider<T>,
        updateClosure: @escaping (T?) -> Void,
        failureClosure: @escaping (Error) -> Void,
        callbackQueue: DispatchQueue,
        options: DataProviderObserverOptions
    ) {
        let update = { (changes: [DataProviderChange<T>]) in
            let value = changes.reduceToLastChange()
            updateClosure(value)
        }

        let failure = { error in
            failureClosure(error)
        }

        provider.addObserver(
            self,
            deliverOn: callbackQueue,
            executing: update,
            failing: failure,
            options: options
        )
    }

    func addStreamableProviderObserver<T: Identifiable>(
        for provider: StreamableProvider<T>,
        updateClosure: @escaping ([DataProviderChange<T>]) -> Void,
        failureClosure: @escaping (Error) -> Void,
        callbackQueue: DispatchQueue,
        options: StreamableProviderObserverOptions
    ) {
        provider.addObserver(
            self,
            deliverOn: callbackQueue,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func addStreamableProviderObserver<T: Identifiable>(
        for provider: StreamableProvider<T>,
        updateClosure: @escaping ([DataProviderChange<T>]) -> Void,
        failureClosure: @escaping (Error) -> Void,
        options: StreamableProviderObserverOptions = .allNonblocking()
    ) {
        addStreamableProviderObserver(
            for: provider,
            updateClosure: updateClosure,
            failureClosure: failureClosure,
            callbackQueue: .main,
            options: options
        )
    }
}
