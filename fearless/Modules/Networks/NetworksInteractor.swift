import UIKit
import RobinHood
import SoraKeystore
import IrohaCrypto

final class NetworksInteractor {
    weak var presenter: NetworksInteractorOutputProtocol!

//    let connectionsObservable: AnyDataProviderRepositoryObservable<ManagedConnectionItem>
//    let connectionsRepository: AnyDataProviderRepository<ManagedConnectionItem>
//    let accountsRepository: AnyDataProviderRepository<ManagedAccountItem>
//    private(set) var settings: SettingsManagerProtocol
//    let operationManager: OperationManagerProtocol
//    let eventCenter: EventCenterProtocol
//
//    init(
//        connectionsRepository: AnyDataProviderRepository<ManagedConnectionItem>,
//        connectionsObservable: AnyDataProviderRepositoryObservable<ManagedConnectionItem>,
//        accountsRepository: AnyDataProviderRepository<ManagedAccountItem>,
//        settings: SettingsManagerProtocol,
//        operationManager: OperationManagerProtocol,
//        eventCenter: EventCenterProtocol
//    ) {
//        self.connectionsRepository = connectionsRepository
//        self.connectionsObservable = connectionsObservable
//        self.accountsRepository = accountsRepository
//        self.settings = settings
//        self.operationManager = operationManager
//        self.eventCenter = eventCenter
//    }

//    private func provideDefaultConnections() {
//        presenter.didReceiveDefaultConnections(ConnectionItem.supportedConnections)
//    }
//
//    private func provideCustomConnections() {
//        let options = RepositoryFetchOptions()
//        let operation = connectionsRepository.fetchAllOperation(with: options)
//
//        operation.completionBlock = { [weak self] in
//            DispatchQueue.main.async {
//                do {
//                    let items = try operation
//                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
//                    let changes = items.map { DataProviderChange.insert(newItem: $0) }
//
//                    self?.presenter.didReceiveCustomConnection(changes: changes)
//                } catch {
//                    self?.presenter.didReceiveCustomConnection(error: error)
//                }
//            }
//        }
//
//        operationManager.enqueue(operations: [operation], in: .transient)
//    }
//
//    private func provideSelectedItem() {
//        presenter.didReceiveSelectedConnection(settings.selectedConnection)
//    }
//
//    private func select(
//        connection: ConnectionItem,
//        for accountsFetchResult: Result<[ManagedAccountItem], Error>?
//    ) {
//        guard let result = accountsFetchResult else {
//            presenter.didReceiveConnection(selectionError: BaseOperationError.parentOperationCancelled)
//            return
//        }
//
//        switch result {
//        case let .success(accounts):
//            let filteredAccounts: [AccountItem] = accounts.compactMap { managedAccount in
//                if managedAccount.networkType == connection.type {
//                    return AccountItem(managedItem: managedAccount)
//                } else {
//                    return nil
//                }
//            }
//
//            if filteredAccounts.isEmpty {
//                presenter.didFindNoAccounts(for: connection)
//            } else if filteredAccounts.count > 1 {
//                presenter.didFindMultiple(accounts: filteredAccounts, for: connection)
//            } else if let account = filteredAccounts.first {
//                select(connection: connection, account: account)
//            }
//
//        case let .failure(error):
//            presenter.didReceiveConnection(selectionError: error)
//        }
//    }
}

extension NetworksInteractor: NetworksInteractorInputProtocol {
    func setup() {}
}
