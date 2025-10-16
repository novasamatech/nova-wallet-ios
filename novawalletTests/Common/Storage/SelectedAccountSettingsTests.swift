import XCTest
@testable import novawallet
import Operation_iOS

class SelectedAccountSettingsTests: XCTestCase {
    struct Common {
        let operationQueue: OperationQueue
        let selectedAccountSettings: SelectedWalletSettings
        let repository: AnyDataProviderRepository<ManagedMetaAccountModel>

        init() {
            operationQueue = OperationQueue()
            let facade = UserDataStorageTestFacade()

            selectedAccountSettings = SelectedWalletSettings(
                storageFacade: facade,
                operationQueue: operationQueue
            )

            let mapper = ManagedMetaAccountMapper()
            let coreDataRepository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))
            repository = AnyDataProviderRepository(coreDataRepository)
        }
    }

    let initialSelectedWallet = ManagedMetaAccountModel(
        info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 2),
        isSelected: true
    )

    let otherWallet = ManagedMetaAccountModel(
        info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 2),
        isSelected: false
    )

    func testSelectFirst() throws {
        // given

        let common = Common()

        // when

        common.selectedAccountSettings.setup(runningCompletionIn: .global()) { _ in }

        XCTAssertNil(common.selectedAccountSettings.value)

        common.selectedAccountSettings.save(value: initialSelectedWallet.info, runningCompletionIn: .global()) { _ in }

        // then

        XCTAssertEqual(common.selectedAccountSettings.value, initialSelectedWallet.info)

        let allMetaAccountsOperation = common.repository.fetchAllOperation(with: RepositoryFetchOptions())
        common.operationQueue.addOperations([allMetaAccountsOperation], waitUntilFinished: true)

        let allMetaAccounts = try allMetaAccountsOperation.extractNoCancellableResultData()

        XCTAssertEqual(initialSelectedWallet.info, allMetaAccounts.first?.info)
        XCTAssertEqual(allMetaAccounts.count, 1)
        XCTAssertEqual(allMetaAccounts.first?.isSelected, true)
    }

    func testChangeSelectedWallet() throws {
        // given

        let common = Common()

        let saveOperation = common.repository.saveOperation({ [self.initialSelectedWallet] }, { [] })
        common.operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        // when

        common.selectedAccountSettings.setup(runningCompletionIn: .global()) { _ in }

        XCTAssertEqual(common.selectedAccountSettings.value, initialSelectedWallet.info)

        common.selectedAccountSettings.save(value: otherWallet.info, runningCompletionIn: .global()) { _ in }

        // then

        XCTAssertEqual(common.selectedAccountSettings.value, otherWallet.info)

        let allMetaAccountsOperation = common.repository.fetchAllOperation(with: RepositoryFetchOptions())
        common.operationQueue.addOperations([allMetaAccountsOperation], waitUntilFinished: true)

        let allMetaAccounts = try allMetaAccountsOperation.extractNoCancellableResultData()

        let expectedAccounts = [initialSelectedWallet.info, otherWallet.info].reduce(
            into: [String: MetaAccountModel]()
        ) { result, account in
            result[account.metaId] = account
        }

        let actualAccounts = allMetaAccounts.reduce(into: [String: MetaAccountModel]()) { result, account in
            result[account.identifier] = account.info
        }

        XCTAssertEqual(expectedAccounts, actualAccounts)
    }

    func testRemoveSelectedWallet() throws {
        // given

        let common = Common()

        let saveOperation = common.repository.saveOperation({ [self.initialSelectedWallet, self.otherWallet] }, { [] })
        common.operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        // when

        common.selectedAccountSettings.setup(runningCompletionIn: .global()) { _ in }

        XCTAssertEqual(common.selectedAccountSettings.value, initialSelectedWallet.info)

        common.selectedAccountSettings.remove(value: initialSelectedWallet.info)

        // then

        XCTAssertEqual(common.selectedAccountSettings.value, otherWallet.info)

        let allMetaAccountsOperation = common.repository.fetchAllOperation(with: RepositoryFetchOptions())
        common.operationQueue.addOperations([allMetaAccountsOperation], waitUntilFinished: true)

        let allMetaAccounts = try allMetaAccountsOperation.extractNoCancellableResultData()

        let expectedWallets = [otherWallet.info].reduceToDict()

        let actualWallets = allMetaAccounts.map(\.info).reduceToDict()

        XCTAssertEqual(expectedWallets, actualWallets)

        if let remoteSelectedWallet = allMetaAccounts.first(where: { $0.identifier == otherWallet.identifier }) {
            XCTAssertTrue(remoteSelectedWallet.isSelected)
        } else {
            XCTFail("Can't find selected wallet in database")
        }
    }

    func testRemoveLastWallet() throws {
        // given

        let common = Common()

        let saveOperation = common.repository.saveOperation({ [self.initialSelectedWallet] }, { [] })
        common.operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        // when

        common.selectedAccountSettings.setup(runningCompletionIn: .global()) { _ in }

        XCTAssertEqual(common.selectedAccountSettings.value, initialSelectedWallet.info)

        common.selectedAccountSettings.remove(value: initialSelectedWallet.info)

        // then

        XCTAssertEqual(common.selectedAccountSettings.value, nil)

        let allMetaAccountsOperation = common.repository.fetchAllOperation(with: RepositoryFetchOptions())
        common.operationQueue.addOperations([allMetaAccountsOperation], waitUntilFinished: true)

        let allMetaAccounts = try allMetaAccountsOperation.extractNoCancellableResultData()

        XCTAssertTrue(allMetaAccounts.isEmpty)
    }
}
