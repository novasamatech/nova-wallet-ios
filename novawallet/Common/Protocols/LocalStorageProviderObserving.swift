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
}
