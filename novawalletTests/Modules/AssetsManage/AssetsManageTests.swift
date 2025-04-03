import XCTest
@testable import novawallet
import Keystore_iOS
import Operation_iOS
import Foundation_iOS
import Cuckoo

class AssetsManageTests: XCTestCase {
    func testSetupAndSave() {
        // given

        let view = MockTokensManageViewProtocol()
        let wireframe = MockTokensManageWireframeProtocol()

        let settingsManager = InMemorySettingsManager()
        settingsManager.hidesZeroBalances = true

        let storageFacade = SubstrateStorageTestFacade()
        
        let mapper = ChainModelMapper()
        let repository: CoreDataRepository<ChainModel, CDChain> = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(mapper)
        )
        let operationQueue = OperationQueue()
        let eventCenter = MockEventCenterProtocol()
        
        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: Set())

        let interactor = TokensManageInteractor(
            chainRegistry: chainRegistry,
            eventCenter: eventCenter,
            settingsManager: settingsManager,
            repository: AnyDataProviderRepository(repository),
            repositoryFactory: SubstrateRepositoryFactory(storageFacade: storageFacade),
            operationQueue: operationQueue
        )
        
        let viewModelFactory = TokensManageViewModelFactory(
            quantityFormater: NumberFormatter.positiveQuantity.localizableResource(), 
            assetIconViewModelFactory: AssetIconViewModelFactory()
        )
        
        let presenter = TokensManagePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        // when

        var reeceivedFilter: Bool?
        let expectedFilter = true

        let setupCompletion = XCTestExpectation()

        stub(view) { stub in
            stub.didReceive(hidesZeroBalances: any()).then { hidesZeroBalances in
                reeceivedFilter = hidesZeroBalances
                
                setupCompletion.fulfill()
            }
            
            stub.didReceive(viewModels: any()).thenDoNothing()
        }

        presenter.setup()

        // then

        wait(for: [setupCompletion], timeout: 1.0)

        XCTAssertEqual(reeceivedFilter, expectedFilter)

        // when

        let notificationExpectation = XCTestExpectation()

        stub(eventCenter) { stub in
            stub.notify(with: any()).then { event in
                notificationExpectation.fulfill()
            }
        }

        presenter.performFilterChange(to: !expectedFilter)

        // then

        wait(for: [notificationExpectation], timeout: 1.0)

        XCTAssertEqual(settingsManager.hidesZeroBalances, !expectedFilter)
    }
}
