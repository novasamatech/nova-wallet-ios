import XCTest
@testable import novawallet
import BigInt
import Operation_iOS
import Cuckoo

final class SubtensorSubnetsServiceTests: XCTestCase {
    func testFetchMergesSubnetsPricesAndSubtokenEnabled() throws {
        let subnets = [
            generateDynamicInfo(netuid: 0, name: "root"),
            generateDynamicInfo(netuid: 1, name: "Apex"),
            generateDynamicInfo(netuid: 5, name: "OpenKaito")
        ]

        let prices = [
            SubtensorStakingPallet.SubnetPrice(netuid: 0, price: 1_000_000_000),
            SubtensorStakingPallet.SubnetPrice(netuid: 1, price: 7_683_255),
            SubtensorStakingPallet.SubnetPrice(netuid: 5, price: 12_672_077)
        ]

        let service = createService(
            apiFactory: createApiFactory(subnets: subnets, prices: prices, subtokenEnabled: [1, 5])
        )

        let info = try fetchInfo(using: service)

        XCTAssertEqual(info.subnets, subnets)
        XCTAssertEqual(info.prices, [0: 1_000_000_000, 1: 7_683_255, 5: 12_672_077])
        XCTAssertEqual(info.subtokenEnabled, [1, 5])
    }

    func testSubtokenEnabledFailureFailsFetch() {
        let apiFactory = createApiFactory(
            subnets: [generateDynamicInfo(netuid: 1, name: "Apex")],
            prices: [],
            subtokenEnabled: [1]
        )

        stub(apiFactory) { stub in
            when(stub.createSubtokenEnabledWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
            }
        }

        XCTAssertThrowsError(try fetchInfo(using: createService(apiFactory: apiFactory)))
    }

    private func generateDynamicInfo(netuid: UInt16, name: String) -> SubtensorStakingPallet.DynamicInfo {
        SubtensorStakingPallet.DynamicInfo(
            netuid: netuid,
            ownerHotkey: Data(repeating: 0, count: 32),
            ownerColdkey: Data(repeating: 0, count: 32),
            subnetName: Data(name.utf8),
            tokenSymbol: Data("α".utf8),
            tempo: 360,
            emission: 0,
            alphaIn: 0,
            taoIn: 0,
            taoInEmission: 0,
            networkRegisteredAt: 0
        )
    }

    private func createApiFactory(
        subnets: [SubtensorStakingPallet.DynamicInfo?],
        prices: [SubtensorStakingPallet.SubnetPrice],
        subtokenEnabled: Set<UInt16>
    ) -> MockSubtensorApiOperationFactoryProtocol {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createAllDynamicInfoWrapper(at: any())).then { _ in
                CompoundOperationWrapper.createWithResult(subnets)
            }
            when(stub.createAlphaPricesWrapper()).then {
                CompoundOperationWrapper.createWithResult(prices)
            }
            when(stub.createSubtokenEnabledWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithResult(subtokenEnabled)
            }
        }

        return apiFactory
    }

    private func createService(
        apiFactory: MockSubtensorApiOperationFactoryProtocol
    ) -> SubtensorSubnetsService {
        SubtensorSubnetsService(operationFactory: apiFactory, operationQueue: OperationQueue())
    }

    private func fetchInfo(using service: SubtensorSubnetsService) throws -> SubtensorSubnetsInfo {
        let wrapper = service.createSubnetsInfoWrapper()

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
