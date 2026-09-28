import XCTest
@testable import novawallet
import BigInt
import Operation_iOS
import Cuckoo

final class SubtensorSubnetsServiceTests: XCTestCase {
    func testFetchMergesSubnetsPricesAndSubtokenEnabled() throws {
        let subnets = [
            makeDynamicInfo(netuid: 0, name: "root"),
            makeDynamicInfo(netuid: 1, name: "Apex"),
            makeDynamicInfo(netuid: 5, name: "OpenKaito")
        ]

        let prices = [
            SubtensorStakingPallet.SubnetPrice(netuid: 0, price: 1_000_000_000),
            SubtensorStakingPallet.SubnetPrice(netuid: 1, price: 7_683_255),
            SubtensorStakingPallet.SubnetPrice(netuid: 5, price: 12_672_077)
        ]

        let service = makeService(
            apiFactory: makeApiFactory(subnets: subnets, prices: prices, subtokenEnabled: [1, 5])
        )

        let info = try fetchInfo(using: service)

        XCTAssertEqual(info.subnets, subnets)
        XCTAssertEqual(info.prices, [0: 1_000_000_000, 1: 7_683_255, 5: 12_672_077])
        XCTAssertEqual(info.subtokenEnabled, [1, 5])
    }

    func testSubtokenEnabledQueriedForEveryDecodedNetuid() throws {
        let apiFactory = makeApiFactory(
            subnets: [
                makeDynamicInfo(netuid: 0, name: "root"),
                nil,
                makeDynamicInfo(netuid: 64, name: "Chutes")
            ],
            prices: [],
            subtokenEnabled: [64]
        )

        _ = try fetchInfo(using: makeService(apiFactory: apiFactory))

        let netuidsCaptor = ArgumentCaptor<[UInt16]>()
        let blockHashCaptor = ArgumentCaptor<BlockHash?>()

        verify(apiFactory, times(1)).createSubtokenEnabledWrapper(
            for: netuidsCaptor.capture(),
            blockHash: blockHashCaptor.capture()
        )

        XCTAssertEqual(netuidsCaptor.value, [0, 64])

        let capturedBlockHash = try XCTUnwrap(blockHashCaptor.value)

        XCTAssertNil(capturedBlockHash)
    }

    func testSubtokenEnabledFailureFailsFetch() {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createAllDynamicInfoWrapper(at: any())).thenReturn(
                CompoundOperationWrapper.createWithResult([makeDynamicInfo(netuid: 1, name: "Apex")])
            )
            when(stub.createAlphaPricesWrapper(at: any())).thenReturn(
                CompoundOperationWrapper.createWithResult([])
            )
            when(stub.createSubtokenEnabledWrapper(for: any(), blockHash: any())).thenReturn(
                CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
            )
            when(stub.createSubnetOwnerCutWrapper(blockHash: any())).thenReturn(
                CompoundOperationWrapper.createWithResult(SubtensorStakingPallet.defaultSubnetOwnerCut)
            )
        }

        XCTAssertThrowsError(try fetchInfo(using: makeService(apiFactory: apiFactory)))
    }

    func testOwnerCutIsFetchedOncePerSession() throws {
        let apiFactory = makeApiFactory(
            subnets: [makeDynamicInfo(netuid: 1, name: "Apex")],
            prices: [],
            subtokenEnabled: [1]
        )

        let service = makeService(apiFactory: apiFactory)

        _ = try fetchInfo(using: service)
        _ = try fetchInfo(using: service)

        verify(apiFactory, times(1)).createSubnetOwnerCutWrapper(blockHash: any())
    }

    func testOwnerCutIsFetchedWithSubnetsInfo() throws {
        let apiFactory = makeApiFactory(
            subnets: [makeDynamicInfo(netuid: 1, name: "Apex")],
            prices: [SubtensorStakingPallet.SubnetPrice(netuid: 1, price: 7_683_255)],
            subtokenEnabled: [1],
            ownerCut: 20000
        )

        let info = try fetchInfo(using: makeService(apiFactory: apiFactory))

        XCTAssertEqual(info.ownerCut, 20000)

        let blockHashCaptor = ArgumentCaptor<BlockHash?>()

        verify(apiFactory, times(1)).createSubnetOwnerCutWrapper(blockHash: blockHashCaptor.capture())

        let capturedBlockHash = try XCTUnwrap(blockHashCaptor.value)

        XCTAssertNil(capturedBlockHash)
    }

    func testUnsetOwnerCutFallsBackToRuntimeDefault() throws {
        let apiFactory = makeApiFactory(
            subnets: [makeDynamicInfo(netuid: 1, name: "Apex")],
            prices: [],
            subtokenEnabled: [1],
            ownerCut: nil
        )

        let info = try fetchInfo(using: makeService(apiFactory: apiFactory))

        XCTAssertEqual(info.ownerCut, SubtensorStakingPallet.defaultSubnetOwnerCut)
    }

    func testOwnerCutFailureFailsFetch() {
        let apiFactory = makeApiFactory(
            subnets: [makeDynamicInfo(netuid: 1, name: "Apex")],
            prices: [],
            subtokenEnabled: [1]
        )

        stub(apiFactory) { stub in
            when(stub.createSubnetOwnerCutWrapper(blockHash: any())).thenReturn(
                CompoundOperationWrapper.createWithError(CommonError.dataCorruption)
            )
        }

        XCTAssertThrowsError(try fetchInfo(using: makeService(apiFactory: apiFactory)))
    }

    func testSecondFetchWithinSessionServesCache() throws {
        let apiFactory = makeApiFactory(
            subnets: [makeDynamicInfo(netuid: 1, name: "Apex")],
            prices: [SubtensorStakingPallet.SubnetPrice(netuid: 1, price: 7_683_255)],
            subtokenEnabled: [1]
        )

        let service = makeService(apiFactory: apiFactory)

        let firstInfo = try fetchInfo(using: service)
        let secondInfo = try fetchInfo(using: service)

        XCTAssertEqual(firstInfo, secondInfo)
        verify(apiFactory, times(1)).createAllDynamicInfoWrapper(at: any())
        verify(apiFactory, times(1)).createSubtokenEnabledWrapper(for: any(), blockHash: any())
    }

    func testForcedRefreshBypassesTheSessionCache() throws {
        let apex = makeDynamicInfo(netuid: 1, name: "Apex")
        let chutes = makeDynamicInfo(netuid: 64, name: "Chutes")

        let apiFactory = makeApiFactory(subnets: [apex], prices: [], subtokenEnabled: [1])
        let service = makeService(apiFactory: apiFactory)

        _ = try fetchInfo(using: service)

        stub(apiFactory) { stub in
            when(stub.createAllDynamicInfoWrapper(at: any())).then { _ in
                CompoundOperationWrapper.createWithResult([apex, chutes])
            }
        }

        let refreshExpectation = expectation(description: "forced subnets fetch")
        var refreshResult: Result<SubtensorSubnetsInfo, Error>?

        service.fetchSubnetsInfo(forcingRefresh: true, runningCompletionIn: .main) { result in
            refreshResult = result
            refreshExpectation.fulfill()
        }

        wait(for: [refreshExpectation], timeout: 10)

        XCTAssertEqual(try XCTUnwrap(refreshResult).get().subnets, [apex, chutes])
    }

    private func makeDynamicInfo(netuid: UInt16, name: String) -> SubtensorStakingPallet.DynamicInfo {
        SubtensorStakingPallet.DynamicInfo(
            netuid: netuid,
            ownerHotkey: Data(repeating: 0, count: 32),
            ownerColdkey: Data(repeating: 0, count: 32),
            subnetName: Data(name.utf8),
            tokenSymbol: Data("α".utf8),
            tempo: 360,
            lastStep: 0,
            blocksSinceLastStep: 0,
            emission: 0,
            alphaIn: 0,
            alphaOut: 0,
            taoIn: 0,
            alphaOutEmission: 0,
            alphaInEmission: 0,
            taoInEmission: 0,
            pendingAlphaEmission: 0,
            pendingRootEmission: 0,
            subnetVolume: 0,
            networkRegisteredAt: 0,
            subnetIdentity: nil,
            movingPrice: .null
        )
    }

    private func makeApiFactory(
        subnets: [SubtensorStakingPallet.DynamicInfo?],
        prices: [SubtensorStakingPallet.SubnetPrice],
        subtokenEnabled: Set<UInt16>,
        ownerCut: UInt16? = SubtensorStakingPallet.defaultSubnetOwnerCut
    ) -> MockSubtensorApiOperationFactoryProtocol {
        let apiFactory = MockSubtensorApiOperationFactoryProtocol()

        stub(apiFactory) { stub in
            when(stub.createAllDynamicInfoWrapper(at: any())).then { _ in
                CompoundOperationWrapper.createWithResult(subnets)
            }
            when(stub.createAlphaPricesWrapper(at: any())).then { _ in
                CompoundOperationWrapper.createWithResult(prices)
            }
            when(stub.createSubtokenEnabledWrapper(for: any(), blockHash: any())).then { _, _ in
                CompoundOperationWrapper.createWithResult(subtokenEnabled)
            }
            when(stub.createSubnetOwnerCutWrapper(blockHash: any())).then { _ in
                CompoundOperationWrapper.createWithResult(ownerCut)
            }
        }

        return apiFactory
    }

    private func makeService(
        apiFactory: MockSubtensorApiOperationFactoryProtocol
    ) -> SubtensorSubnetsService {
        SubtensorSubnetsService(
            operationFactory: apiFactory,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    private func fetchInfo(using service: SubtensorSubnetsService) throws -> SubtensorSubnetsInfo {
        let fetchExpectation = expectation(description: "subnets fetch")
        var fetchResult: Result<SubtensorSubnetsInfo, Error>?

        service.fetchSubnetsInfo(runningCompletionIn: .main) { result in
            fetchResult = result
            fetchExpectation.fulfill()
        }

        wait(for: [fetchExpectation], timeout: 10)

        return try XCTUnwrap(fetchResult).get()
    }
}
