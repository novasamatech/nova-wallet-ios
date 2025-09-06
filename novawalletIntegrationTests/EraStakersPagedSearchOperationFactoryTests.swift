import XCTest
@testable import novawallet
import Operation_iOS

final class EraStakersPagedSearchOperationFactoryTests: XCTestCase {
    func testWestendAllEras() {
        let chainId = KnowChainId.westend
        let eraRange = EraRange(start: 1, end: 7352)

        do {
            let era = try findEra(for: chainId, eraRange: eraRange)
            Logger.shared.info("Found era: \(String(describing: era))")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWestendAllMatchingEras() {
        let chainId = KnowChainId.westend
        let eraRange = EraRange(start: 7300, end: 7352)

        do {
            let era = try findEra(for: chainId, eraRange: eraRange)
            Logger.shared.info("Found era: \(String(describing: era))")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWestendAllNonMatchingEras() {
        let chainId = KnowChainId.westend
        let eraRange = EraRange(start: 1, end: 7268)

        do {
            let era = try findEra(for: chainId, eraRange: eraRange)
            Logger.shared.info("Found era: \(String(describing: era))")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWestendLastMatchingEras() {
        let chainId = KnowChainId.westend
        let eraRange = EraRange(start: 1, end: 7269)

        do {
            let era = try findEra(for: chainId, eraRange: eraRange)
            Logger.shared.info("Found era: \(String(describing: era))")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWestendFirstMatchingEras() {
        let chainId = KnowChainId.westend
        let eraRange = EraRange(start: 7269, end: 7352)

        do {
            let era = try findEra(for: chainId, eraRange: eraRange)
            Logger.shared.info("Found era: \(String(describing: era))")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWestendSingleMatchingEra() {
        let chainId = KnowChainId.westend
        let eraRange = EraRange(start: 7269, end: 7269)

        do {
            let era = try findEra(for: chainId, eraRange: eraRange)
            Logger.shared.info("Found era: \(String(describing: era))")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWestendSingleNotMatchingEra() {
        let chainId = KnowChainId.westend
        let eraRange = EraRange(start: 7268, end: 7268)

        do {
            let era = try findEra(for: chainId, eraRange: eraRange)
            Logger.shared.info("Found era: \(String(describing: era))")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWestendInvalidRangeEra() {
        let chainId = KnowChainId.westend
        let eraRange = EraRange(start: 7269, end: 7268)

        do {
            let era = try findEra(for: chainId, eraRange: eraRange)
            Logger.shared.info("Found era: \(String(describing: era))")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testKusamaAllRange() {
        let chainId = KnowChainId.kusama
        let eraRange = EraRange(start: 0, end: 6136)

        do {
            let era = try findEra(for: chainId, eraRange: eraRange)
            Logger.shared.info("Found era: \(String(describing: era))")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPolkadotAllRange() {
        let chainId = KnowChainId.polkadot
        let eraRange = EraRange(start: 0, end: 1322)

        do {
            let era = try findEra(for: chainId, eraRange: eraRange)
            Logger.shared.info("Found era: \(String(describing: era))")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAzeroAllRange() {
        let chainId = KnowChainId.alephZero
        let eraRange = EraRange(start: 0, end: 627)

        do {
            let era = try findEra(for: chainId, eraRange: eraRange)
            Logger.shared.info("Found era: \(String(describing: era))")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func findEra(for chainId: ChainModel.Id, eraRange: EraRange) throws -> EraIndex? {
        // given

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistryFacade = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard
            let connection = chainRegistryFacade.getConnection(for: chainId),
            let runtimeProvider = chainRegistryFacade.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let operationQueue = OperationQueue()

        let operationFactory = ExposurePagedEraOperationFactory(operationQueue: operationQueue)

        // when

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper = operationFactory.createWrapper(
            for: { eraRange },
            codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() },
            connection: connection
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        let allOperations = [codingFactoryOperation] + wrapper.allOperations

        operationQueue.addOperations(allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
