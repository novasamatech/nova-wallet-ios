import Foundation
import Operation_iOS

protocol AssetVisibilityWriting: AnyObject {
    func setState(
        metaId: MetaAccountModel.Id,
        ids: Set<ChainAssetId>,
        state: AssetVisibilityState,
        runningCallbackIn queue: DispatchQueue?,
        completion: ((Result<Void, Error>) -> Void)?
    )

    func showIfUndecided(metaId: MetaAccountModel.Id, ids: Set<ChainAssetId>)

    func enqueueBarrier(callbackIn queue: DispatchQueue, completion: @escaping () -> Void)
}

final class AssetVisibilityWriter {
    static let shared = AssetVisibilityWriter(
        storageFacade: UserDataStorageFacade.shared,
        writeQueue: OperationManagerFacade.assetVisibilityQueue,
        workQueue: OperationManagerFacade.sharedDefaultQueue,
        logger: Logger.shared
    )

    private let storageFacade: StorageFacadeProtocol
    private let writeQueue: OperationQueue
    private let workQueue: OperationQueue
    private let logger: LoggerProtocol

    init(
        storageFacade: StorageFacadeProtocol,
        writeQueue: OperationQueue,
        workQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.storageFacade = storageFacade
        self.writeQueue = writeQueue
        self.workQueue = workQueue
        self.logger = logger
    }
}

// MARK: AssetVisibilityWriting

extension AssetVisibilityWriter: AssetVisibilityWriting {
    func setState(
        metaId: MetaAccountModel.Id,
        ids: Set<ChainAssetId>,
        state: AssetVisibilityState,
        runningCallbackIn queue: DispatchQueue?,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        let operation = ClosureOperation<Void> { [weak self] in
            guard let self else {
                throw CommonError.undefined
            }

            let rows = ids.map {
                AssetVisibilityLocal(
                    metaId: metaId,
                    chainId: $0.chainId,
                    assetId: $0.assetId,
                    state: state
                )
            }

            try save(rows: rows, for: metaId)
        }

        execute(
            operation: operation,
            inOperationQueue: writeQueue,
            runningCallbackIn: queue
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Can't save visibility of \(ids.count) assets: \(error)")
            }

            completion?(result)
        }
    }

    func showIfUndecided(metaId: MetaAccountModel.Id, ids: Set<ChainAssetId>) {
        guard !ids.isEmpty else {
            return
        }

        let operation = ClosureOperation<Void> { [weak self] in
            guard let self else {
                throw CommonError.undefined
            }

            let states = try fetchStates(for: metaId)

            let undecided = ids.filter { states[$0] == nil || states[$0] == .hiddenUntilBalance }

            guard !undecided.isEmpty else {
                return
            }

            let rows = undecided.map {
                AssetVisibilityLocal(
                    metaId: metaId,
                    chainId: $0.chainId,
                    assetId: $0.assetId,
                    state: .visible
                )
            }

            try save(rows: rows, for: metaId)
        }

        execute(
            operation: operation,
            inOperationQueue: writeQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Can't reveal \(ids.count) assets: \(error)")
            }
        }
    }

    func enqueueBarrier(callbackIn queue: DispatchQueue, completion: @escaping () -> Void) {
        let operation = ClosureOperation<Void> {}

        execute(
            operation: operation,
            inOperationQueue: writeQueue,
            runningCallbackIn: queue
        ) { _ in
            completion()
        }
    }
}

// MARK: Private

private extension AssetVisibilityWriter {
    func save(rows: [AssetVisibilityLocal], for metaId: MetaAccountModel.Id) throws {
        let repository = AssetVisibilityRepositoryFactory.createVisibilityRepository(
            for: metaId,
            using: storageFacade
        )

        let saveOperation = repository.saveOperation({ rows }, { [] })

        workQueue.addOperations([saveOperation], waitUntilFinished: true)

        try saveOperation.extractNoCancellableResultData()
    }

    func fetchStates(
        for metaId: MetaAccountModel.Id
    ) throws -> [ChainAssetId: AssetVisibilityState] {
        let repository = AssetVisibilityRepositoryFactory.createVisibilityRepository(
            for: metaId,
            using: storageFacade
        )

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        workQueue.addOperations([fetchOperation], waitUntilFinished: true)

        let rows = try fetchOperation.extractNoCancellableResultData()

        return rows.reduce(into: [:]) { $0[$1.chainAssetId] = $1.state }
    }
}
