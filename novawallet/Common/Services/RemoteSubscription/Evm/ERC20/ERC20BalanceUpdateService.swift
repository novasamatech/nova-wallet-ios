import Foundation
import RobinHood
import web3swift
import Core
import SubstrateSdk
import BigInt

typealias ERC20UpdateServiceCompletionClosure = () -> Void

final class ERC20BalanceUpdateService: BaseSyncService, AnyCancellableCleaning {
    let holder: AccountAddress
    let assetContracts: Set<EvmAssetContractId>
    let connection: JSONRPCEngine
    let repository: AnyDataProviderRepository<AssetBalance>
    let operationQueue: OperationQueue
    let blockNumber: Core.BlockNumber
    let queryMessageFactory: EvmQueryContractMessageFactoryProtocol
    let completion: ERC20UpdateServiceCompletionClosure?

    @Atomic(defaultValue: nil) private var queryIds: [UInt16]?
    @Atomic(defaultValue: nil) private var cancellable: CancellableCall?

    init(
        holder: AccountAddress,
        assetContracts: Set<EvmAssetContractId>,
        connection: JSONRPCEngine,
        repository: AnyDataProviderRepository<AssetBalance>,
        operationQueue: OperationQueue,
        blockNumber: Core.BlockNumber,
        queryMessageFactory: EvmQueryContractMessageFactoryProtocol,
        logger: LoggerProtocol?,
        completion: ERC20UpdateServiceCompletionClosure?
    ) {
        self.holder = holder
        self.assetContracts = assetContracts
        self.connection = connection
        self.repository = repository
        self.operationQueue = operationQueue
        self.blockNumber = blockNumber
        self.queryMessageFactory = queryMessageFactory
        self.completion = completion

        super.init(logger: logger)
    }

    private func createSaveOperation(
        dependingOn localBalancesOperation: BaseOperation<[ChainAssetId: AssetBalance]>,
        balances: [ChainAssetId: BigUInt],
        holder: AccountAddress
    ) -> BaseOperation<Void> {
        repository.saveOperation({
            let localBalancesDict = try localBalancesOperation.extractNoCancellableResultData()

            let accountId = try holder.toEthereumAccountId()

            return balances.compactMap { keyValue in
                // add new balance or update existing

                let chainAssetId = keyValue.key
                let newBalance = keyValue.value
                let oldBalance = localBalancesDict[chainAssetId]?.totalInPlank

                guard newBalance > 0, newBalance != oldBalance else {
                    return nil
                }

                return AssetBalance(
                    chainAssetId: chainAssetId,
                    accountId: accountId,
                    freeInPlank: newBalance,
                    reservedInPlank: 0,
                    frozenInPlank: 0,
                    blocked: false
                )
            }
        }, {
            // remove zero balances

            let localBalancesDict = try localBalancesOperation.extractNoCancellableResultData()

            return balances.compactMap { keyValue in
                let chainAssetId = keyValue.key
                let newBalance = keyValue.value

                guard newBalance == 0, let oldBalance = localBalancesDict[chainAssetId] else {
                    return nil
                }

                return oldBalance.identifier
            }
        })
    }

    private func saveAndComplete(balances: [ChainAssetId: BigUInt], holder: AccountAddress) {
        let localBalancesFetchOperation = repository.fetchAllOperation(
            with: RepositoryFetchOptions()
        )

        let localBalancesMapOperation = ClosureOperation<[ChainAssetId: AssetBalance]> {
            let localAssetBalances = try localBalancesFetchOperation.extractNoCancellableResultData()
            return localAssetBalances.reduce(into: [ChainAssetId: AssetBalance]()) {
                $0[$1.chainAssetId] = $1
            }
        }

        localBalancesMapOperation.addDependency(localBalancesFetchOperation)

        let saveOperation = createSaveOperation(
            dependingOn: localBalancesMapOperation,
            balances: balances,
            holder: holder
        )

        saveOperation.addDependency(localBalancesMapOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [localBalancesFetchOperation, localBalancesMapOperation]
        )

        saveOperation.completionBlock = { [weak self] in
            guard self?.cancellable === wrapper else {
                return
            }

            self?.cancellable = nil

            do {
                try saveOperation.extractNoCancellableResultData()
                self?.complete(nil)
                self?.completion?()
            } catch {
                self?.complete(error)
            }
        }

        cancellable = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
    }

    private func extractBalances(
        from responses: [Result<JSON, Error>],
        assetContracts: [EvmAssetContractId]
    ) -> [ChainAssetId: BigUInt] {
        zip(assetContracts, responses).reduce(
            into: [ChainAssetId: BigUInt]()
        ) { accum, contractAndResponse in
            let assetContract = contractAndResponse.0

            switch contractAndResponse.1 {
            case let .success(json):
                if
                    let amountString = json.stringValue,
                    let amount = BigUInt.fromHexString(amountString) {
                    accum[assetContract.chainAssetId] = amount
                } else {
                    logger?.error("Unexpected format: \(json)")
                }
            case let .failure(error):
                logger?.error("Unexpected error: \(error)")
            }
        }
    }

    private func fetchBalances(
        for holder: AccountAddress,
        assetContracts: Set<EvmAssetContractId>
    ) {
        let batchId = UUID().uuidString

        let assetContractList = Array(assetContracts)

        do {
            for assetContract in assetContractList {
                let call = try queryMessageFactory.erc20Balance(
                    of: holder,
                    contractAddress: assetContract.contract
                )

                let params = EvmQueryMessage.Params(call: call, block: blockNumber)
                try connection.addBatchCallMethod(EvmQueryMessage.method, params: params, batchId: batchId)
            }

            queryIds = try connection.submitBatch(
                for: batchId,
                options: JSONRPCOptions(resendOnReconnect: true)
            ) { [weak self] responses in
                guard let balances = self?.extractBalances(
                    from: responses,
                    assetContracts: assetContractList
                ) else {
                    return
                }

                self?.saveAndComplete(balances: balances, holder: holder)
            }
        } catch {
            connection.clearBatch(for: batchId)
            complete(error)
        }
    }

    override func performSyncUp() {
        fetchBalances(for: holder, assetContracts: assetContracts)
    }

    override func stopSyncUp() {
        if let queryIds = queryIds {
            connection.cancelForIdentifiers(queryIds)
        }

        clear(cancellable: &cancellable)
    }
}
