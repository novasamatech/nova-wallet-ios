import XCTest
@testable import novawallet
import Keystore_iOS
import Operation_iOS

class CrowdloadSettingsTests: XCTestCase {
    func testSetupWhenChainExists() throws {
        // given

        let (crowdloadSettings, chains) = prepare()

        let settingValue = chains.first!
        crowdloadSettings.settings.crowdloanChainId = settingValue.chainId

        // when

        crowdloadSettings.setup()

        // then

        XCTAssertEqual(settingValue, crowdloadSettings.value)
    }

    func testSetupWhenChainNotExists() throws {
        // given

        let (crowdloadSettings, chains) = prepare()

        let settingValue = ChainModelGenerator.generateChain(generatingAssets: 2, addressPrefix: 42)
        crowdloadSettings.settings.crowdloanChainId = settingValue.chainId

        // when

        crowdloadSettings.setup()

        // then

        XCTAssertNotEqual(settingValue, crowdloadSettings.value)
        XCTAssertTrue(chains.contains(crowdloadSettings.value))
    }

    func testSetupWhenChainNotSelected() throws {
        // given

        let (crowdloadSettings, chains) = prepare()

        // when

        crowdloadSettings.setup()

        // then

        XCTAssertTrue(chains.contains(crowdloadSettings.value))
    }

    func testSaveWhenChainExists() throws {
        // given

        let (crowdloadSettings, chains) = prepare()

        let settingValue = chains.first!
        crowdloadSettings.settings.crowdloanChainId = settingValue.chainId

        // when

        crowdloadSettings.setup()

        let newValue = chains.last!
        crowdloadSettings.save(value: newValue)

        // then

        XCTAssertEqual(newValue, crowdloadSettings.value)
        XCTAssertEqual(crowdloadSettings.settings.crowdloanChainId, newValue.chainId)
    }

    func testSaveWhenChainNotSet() throws {
        // given

        let (crowdloadSettings, chains) = prepare()

        // when

        crowdloadSettings.setup()

        let newValue = chains.last!
        crowdloadSettings.save(value: newValue)

        // then

        XCTAssertEqual(newValue, crowdloadSettings.value)
        XCTAssertEqual(crowdloadSettings.settings.crowdloanChainId, newValue.chainId)
    }

    private func prepare() -> (CrowdloanChainSettings, [ChainModel]) {
        let facade = SubstrateStorageTestFacade()

        let chainMapper = AnyCoreDataMapper(ChainModelMapper())
        let repository = facade.createRepository(mapper: chainMapper)

        let prefs = InMemorySettingsManager()
        let operationQueue = OperationQueue()

        let chains: [ChainModel] = (0..<10).map { index in
            ChainModelGenerator.generateChain(
                generatingAssets: 2,
                addressPrefix: ChainModel.AddressPrefix(index),
                hasCrowdloans: true
            )
        }

        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: Set(chains))

        let settings = CrowdloanChainSettings(chainRegistry: chainRegistry, settings: prefs)

        let saveOperation = repository.saveOperation({ chains }, { [] })
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)

        return (settings, chains)
    }
}
