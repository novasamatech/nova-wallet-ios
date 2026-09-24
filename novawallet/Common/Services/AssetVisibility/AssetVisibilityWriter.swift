import Foundation
import Operation_iOS

protocol AssetVisibilityWriting: AnyObject {
    func apply(
        event: AssetVisibilityEvent,
        metaId: MetaAccountModel.Id,
        ids: Set<ChainAssetId>,
        runningCallbackIn queue: DispatchQueue?,
        completion: ((Result<Void, Error>) -> Void)?
    )
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
    func apply(
        event: AssetVisibilityEvent,
        metaId: MetaAccountModel.Id,
        ids: Set<ChainAssetId>,
        runningCallbackIn queue: DispatchQueue?,
        completion: ((Result<Void, Error>) -> Void)?
    ) {
        let operation = ClosureOperation<Void> { [weak self] in
            guard let self else {
                throw CommonError.undefined
            }

            let states = try fetchStates(for: metaId)

            let rows = ids.compactMap { id -> AssetVisibilityLocal? in
                guard case let .set(state) = AssetVisibilityPolicy.decision(
                    for: event,
                    currentState: states[id]
                ) else {
                    return nil
                }

                return AssetVisibilityLocal(
                    metaId: metaId,
                    chainId: id.chainId,
                    assetId: id.assetId,
                    state: state
                )
            }

            guard !rows.isEmpty else {
                return
            }

            try save(rows: rows, for: metaId)
        }

        execute(
            operation: operation,
            inOperationQueue: writeQueue,
            runningCallbackIn: queue
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Can't apply visibility event to \(ids.count) assets: \(error)")
            }

            completion?(result)
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
