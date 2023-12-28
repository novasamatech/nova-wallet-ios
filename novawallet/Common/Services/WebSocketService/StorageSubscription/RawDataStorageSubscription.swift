import Foundation

final class RawDataStorageSubscription {
    let remoteStorageKey: Data
    let callbackClosure: (Data?, Data?) -> Void

    init(remoteStorageKey: Data, callbackClosure: @escaping (Data?, Data?) -> Void) {
        self.remoteStorageKey = remoteStorageKey
        self.callbackClosure = callbackClosure
    }
}

extension RawDataStorageSubscription: StorageChildSubscribing {
    func processUpdate(_ data: Data?, blockHash: Data?) {
        callbackClosure(data, blockHash)
    }
}
