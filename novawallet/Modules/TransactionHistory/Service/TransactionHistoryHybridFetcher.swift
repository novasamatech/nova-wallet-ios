import Foundation
import RobinHood

final class TransactionHistoryHybridFetcher {
    let remoteOperationFactory: WalletRemoteHistoryFactoryProtocol
    let repository: AnyDataProviderRepository<TransactionHistoryItem>
    let provider: StreamableProvider<>
    let address: AccountAddress
    let chainAsset: ChainAsset
    let pageSize: Int
    let operationQueue: OperationQueue
}
