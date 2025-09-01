import XCTest
@testable import novawallet
import Operation_iOS
import Cuckoo

final class DAppSettingsCleaningTests: XCTestCase {
    func testRemovedWalletDAppSettingsCleanerRemovesSettings() throws {
        // given
        let operationQueue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let mapper = DAppSettingsMapper()
        let repository = facade.createRepository(mapper: AnyCoreDataMapper(mapper))
        let authorizedDAppRepository = AnyDataProviderRepository(repository)
        
        let cleaner = RemovedWalletDAppSettingsCleaner(
            authorizedDAppRepository: authorizedDAppRepository
        )
        
        let removedWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
            isSelected: false,
            order: 0
        )
        let keepWallet = ManagedMetaAccountModel(
            info: AccountGenerator.generateMetaAccount(generatingChainAccounts: 0),
            isSelected: true,
            order: 1
        )
        
        let removedSettings = DAppSettings(
            dAppId: "google.com",
            metaId: removedWallet.info.metaId,
            source: nil
        )
        let keepSettings = DAppSettings(
            dAppId: "novasama.io",
            metaId: keepWallet.info.metaId,
            source: nil
        )
        
        let saveOperation = authorizedDAppRepository.saveOperation(
            { [removedSettings, keepSettings] },
            { [] }
        )
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)
        
        let providers = WalletStorageCleaningProviders(
            changesProvider: {
                [DataProviderChange.delete(deletedIdentifier: removedWallet.identifier)]
            },
            walletsBeforeChangesProvider: {
                [removedWallet.identifier: removedWallet, keepWallet.identifier: keepWallet]
            }
        )
        
        // when
        let wrapper = cleaner.cleanStorage(using: providers)
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        
        // then
        XCTAssertNoThrow(try wrapper.targetOperation.extractNoCancellableResultData())
        
        // Verify settings were removed
        let fetchOperation = authorizedDAppRepository.fetchAllOperation(with: .init())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)
        
        let remainingSettings = try fetchOperation.extractNoCancellableResultData()
        XCTAssertEqual(remainingSettings.count, 1)
        XCTAssertEqual(remainingSettings.first?.metaId, keepWallet.info.metaId)
    }
}
