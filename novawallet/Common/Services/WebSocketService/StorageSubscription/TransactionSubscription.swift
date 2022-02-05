import Foundation
import SubstrateSdk
import IrohaCrypto
import RobinHood
import BigInt

struct TransactionSubscriptionResult {
    let processingResult: ExtrinsicProcessingResult
    let extrinsicHash: Data
    let blockNumber: UInt64
    let txIndex: UInt16
}

final class TransactionSubscription {
    let chainRegistry: ChainRegistryProtocol
    let accountId: AccountId
    let chainModel: ChainModel
    let txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    let storageRequestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        accountId: AccountId,
        chainModel: ChainModel,
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
        storageRequestFactory: StorageRequestFactoryProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.accountId = accountId
        self.chainModel = chainModel
        self.storageRequestFactory = storageRequestFactory
        self.txStorage = txStorage
        self.operationQueue = operationQueue
        self.eventCenter = eventCenter
        self.logger = logger
    }

    func process(blockHash: Data) {
        do {
            logger.debug("Did start fetching block: \(blockHash.toHex(includePrefix: true))")

            guard let connection = chainRegistry.getConnection(for: chainModel.chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            let fetchBlockOperation: JSONRPCOperation<[String], SignedBlock> =
                JSONRPCOperation(
                    engine: connection,
                    method: RPCMethod.getChainBlock,
                    parameters: [blockHash.toHex(includePrefix: true)]
                )

            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainModel.chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let eventsKey = try StorageKeyFactory().key(from: .events)
            let eventsWrapper: CompoundOperationWrapper<[StorageResponse<[EventRecord]>]> =
                storageRequestFactory.queryItems(
                    engine: connection,
                    keys: { [eventsKey] },
                    factory: { try coderFactoryOperation.extractNoCancellableResultData() },
                    storagePath: .events,
                    at: blockHash
                )

            eventsWrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

            let parseOperation = createParseOperation(
                for: accountId,
                dependingOn: fetchBlockOperation,
                eventsOperation: eventsWrapper.targetOperation,
                coderOperation: coderFactoryOperation,
                chain: chainModel
            )

            parseOperation.addDependency(fetchBlockOperation)
            parseOperation.addDependency(eventsWrapper.targetOperation)

            let txSaveOperation = createTxSaveOperation(
                for: accountId,
                chain: chainModel,
                dependingOn: parseOperation,
                codingFactoryOperation: coderFactoryOperation
            )

            txSaveOperation.addDependency(parseOperation)
            txSaveOperation.addDependency(coderFactoryOperation)

            txSaveOperation.completionBlock = {
                switch parseOperation.result {
                case let .success(items):
                    self.logger.debug("Did complete block processing")
                    if !items.isEmpty {
                        DispatchQueue.main.async {
                            self.eventCenter.notify(with: WalletNewTransactionInserted())
                        }
                    }
                case let .failure(error):
                    self.logger.error("Did fail block processing: \(error)")
                case .none:
                    self.logger.error("Block processing cancelled")
                }
            }

            let operations: [Operation] = {
                var array = [Operation]()
                array.append(contentsOf: eventsWrapper.allOperations)
                array.append(fetchBlockOperation)
                array.append(coderFactoryOperation)
                array.append(parseOperation)
                array.append(txSaveOperation)
                return array
            }()

            operationQueue.addOperations(operations, waitUntilFinished: false)
        } catch {
            logger.error("Block processing failed: \(error)")
        }
    }
}

extension TransactionSubscription {
    private func createTxSaveOperation(
        for accountId: AccountId,
        chain: ChainModel,
        dependingOn processingOperaton: BaseOperation<[TransactionSubscriptionResult]>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<Void> {
        txStorage.saveOperation({
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let runtimeJsonContext = codingFactory.createRuntimeJsonContext()
            return try processingOperaton.extractNoCancellableResultData().compactMap { result in
                guard let asset = chain.assets.first(
                    where: { $0.assetId == result.processingResult.assetId }
                ) else {
                    return nil
                }

                return TransactionHistoryItem.createFromSubscriptionResult(
                    result,
                    accountId: accountId,
                    chainAsset: ChainAsset(chain: chain, asset: asset),
                    runtimeJsonContext: runtimeJsonContext
                )
            }
        }, { [] })
    }

    private func createParseOperation(
        for accountId: AccountId,
        dependingOn fetchOperation: BaseOperation<SignedBlock>,
        eventsOperation: BaseOperation<[StorageResponse<[EventRecord]>]>,
        coderOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        chain: ChainModel
    ) -> BaseOperation<[TransactionSubscriptionResult]> {
        ClosureOperation<[TransactionSubscriptionResult]> {
            let block = try fetchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .block

            let eventRecords = try eventsOperation.extractNoCancellableResultData().first?.value ?? []

            guard let blockNumberData = BigUInt.fromHexString(block.header.number) else {
                throw BaseOperationError.unexpectedDependentResult
            }

            let coderFactory = try coderOperation.extractNoCancellableResultData()

            let extrinsicProcessor = ExtrinsicProcessor(accountId: accountId, chain: chain)

            return block.extrinsics.enumerated().compactMap { index, hexExtrinsic in
                do {
                    let data = try Data(hexString: hexExtrinsic)
                    let extrinsicHash = try data.blake2b32()

                    guard let processingResult = extrinsicProcessor.process(
                        extrinsicIndex: UInt32(index),
                        extrinsicData: data,
                        eventRecords: eventRecords,
                        coderFactory: coderFactory
                    ) else {
                        return nil
                    }

                    return TransactionSubscriptionResult(
                        processingResult: processingResult,
                        extrinsicHash: extrinsicHash,
                        blockNumber: UInt64(blockNumberData),
                        txIndex: UInt16(index)
                    )
                } catch {
                    return nil
                }
            }
        }
    }
}
