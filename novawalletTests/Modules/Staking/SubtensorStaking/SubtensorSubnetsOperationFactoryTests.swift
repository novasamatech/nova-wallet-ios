import XCTest
@testable import novawallet
import BigInt
import Operation_iOS
import Cuckoo

final class SubtensorSubnetsOperationFactoryTests: XCTestCase {
    func testFetchMergesSubnetsPricesAndSubtokenEnabled() throws {
        let subnets = [
            generateDynamicInfo(netuid: 0),
            generateDynamicInfo(netuid: 1),
            generateDynamicInfo(netuid: 5)
        ]

        let prices = [
            SubtensorStakingPallet.SubnetPrice(netuid: 0, price: 1_000_000_000),
            SubtensorStakingPallet.SubnetPrice(netuid: 1, price: 7_683_255),
            SubtensorStakingPallet.SubnetPrice(netuid: 5, price: 12_672_077)
        ]

        let operationFactory = createOperationFactory(
            apiFactory: createApiFactory(subnets: subnets, prices: prices, subtokenEnabled: [1, 5])
        )

        let info = try fetchInfo(operationFactory.createSubnetsInfoWrapper())

        XCTAssertEqual(info.subnets, subnets)
        XCTAssertEqual(info.prices, [0: 1_000_000_000, 1: 7_683_255, 5: 12_672_077])
        XCTAssertEqual(info.subtokenEnabled, [1, 5])
    }

    func testSubtokenEnabledFailureFailsFetch() {
        let apiFactory = createApiFactory(
            subnets: [generateDynamicInfo(netuid: 1)],
            prices: [],
            subtokenEnabled: [1]
        )

        stub(apiFactory) { stub in
            when(stub.createSubtokenEnabledWrapper(for: any())).then { _ in
                CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
            }
        }

        XCTAssertThrowsError(try fetchInfo(createOperationFactory(apiFactory: apiFactory).createSubnetsInfoWrapper()))
    }

    func testFetchSubnetWithoutDynamicInfoYieldsEmptyInfo() throws {
        let apiFactory = createApiFactory(subnets: [], prices: [], subtokenEnabled: [5])

        stub(apiFactory) { stub in
            when(stub.createDynamicInfoWrapper(for: any())).then { _ in CompoundOperationWrapper.createWithResult(nil) }
            when(stub.createAlphaPriceWrapper(for: any(), blockHash: any())).then { _ in
                CompoundOperationWrapper.createWithResult(12_672_077)
            }
        }

        let info = try fetchInfo(createOperationFactory(apiFactory: apiFactory).createSubnetInfoWrapper(for: 5))

        XCTAssertEqual(info, SubtensorSubnetsInfo(subnets: [], prices: [:], subtokenEnabled: []))
    }

    private func generateDynamicInfo(netuid: UInt16) -> SubtensorStakingPallet.DynamicInfo {
        SubtensorStakingPallet.DynamicInfo(netuid: netuid, taoInEmission: 0, networkRegisteredAt: 0)
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

    private func createOperationFactory(
        apiFactory: MockSubtensorApiOperationFactoryProtocol
    ) -> SubtensorSubnetsOperationFactory {
        SubtensorSubnetsOperationFactory(operationFactory: apiFactory, operationQueue: OperationQueue())
    }

    private func fetchInfo(_ wrapper: CompoundOperationWrapper<SubtensorSubnetsInfo>) throws -> SubtensorSubnetsInfo {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
