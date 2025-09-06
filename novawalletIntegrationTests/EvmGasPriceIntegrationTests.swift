import XCTest
@testable import novawallet
import Operation_iOS
import BigInt
import SubstrateSdk

final class EvmGasPriceIntegrationTests: XCTestCase {
    func testEvmGasProvidersOnMoonbeam() {
        performTest(for: KnowChainId.moonbeam)
    }

    func testEvmGasProvidersOnMoonriver() {
        performTest(for: KnowChainId.moonriver)
    }

    func testEvmGasProvidersOnEthereum() {
        performTest(for: KnowChainId.ethereum)
    }

    private func performTest(for chainId: ChainModel.Id) {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            XCTFail("Unsupported network")
            return
        }

        let operationFactory = EvmWebSocketOperationFactory(connection: connection)

        let providers: [EvmGasPriceProviderProtocol] = [
            EvmLegacyGasPriceProvider(operationFactory: operationFactory),
            EvmMaxPriorityGasPriceProvider(operationFactory: operationFactory)
        ]

        performGasFeeValuesComparison(for: chainId, providers: providers)
    }

    private func performGasFeeValuesComparison(
        for _: ChainModel.Id,
        providers: [EvmGasPriceProviderProtocol]
    ) {
        let wrappers = providers.map { $0.getGasPriceWrapper() }

        let allOperations = wrappers.flatMap(\.allOperations)

        OperationQueue().addOperations(allOperations, waitUntilFinished: true)

        for (index, wrapper) in wrappers.enumerated() {
            do {
                let price = try wrapper.targetOperation.extractNoCancellableResultData()

                Logger.shared.info("Price \(index + 1): \(String(price))")
            } catch {
                XCTFail("Price provider error: \(error)")
            }
        }
    }
}
