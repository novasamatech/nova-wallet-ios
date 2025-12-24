import Foundation
import SubstrateSdk

typealias BlockNumberRemoteSubscriptionClosure = (Result<BlockNumber?, Error>) -> Void

protocol BlockNumberRemoteSubscriptionProtocol: AnyObject {
    func start(callback: @escaping BlockNumberRemoteSubscriptionClosure) throws
    func unsubscribe()
}

final class BlockNumberRemoteSubscription {
    let chainId: ChainModel.Id
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let localKeyFactory: LocalStorageKeyFactoryProtocol

    let mutex = NSLock()

    var currentSubscription: CallbackStorageSubscription<StringScaleMapper<BlockNumber>>?

    init(
        chainId: ChainModel.Id,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        localKeyFactory: LocalStorageKeyFactoryProtocol
    ) {
        self.chainId = chainId
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.localKeyFactory = localKeyFactory
    }

    deinit { unsubscribe() }
}

extension BlockNumberRemoteSubscription: BlockNumberRemoteSubscriptionProtocol {
    func start(callback: @escaping BlockNumberRemoteSubscriptionClosure) throws {
        mutex.lock()
        defer { mutex.unlock() }

        guard currentSubscription == nil else { return }

        let path = SystemPallet.blockNumberPath
        let localKey = try localKeyFactory.createFromStoragePath(path, chainId: chainId)

        let request = UnkeyedSubscriptionRequest(
            storagePath: path,
            localKey: localKey
        )

        currentSubscription = CallbackStorageSubscription<StringScaleMapper<BlockNumber>>(
            request: request,
            connection: connection,
            runtimeService: runtimeProvider,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: workingQueue
        ) { callback($0.map { $0?.value }) }
    }

    func unsubscribe() {
        mutex.lock()
        defer { mutex.unlock() }

        currentSubscription?.unsubscribe()
        currentSubscription = nil
    }
}
