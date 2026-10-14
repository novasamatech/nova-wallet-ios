import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorValidatorCoverageTests: XCTestCase {
    private let hotkey = Data(repeating: 7, count: 32)

    func testCoverageCountsUniqueNonrootPermitNetuidsAndNeverRegistrationsOrRates() throws {
        let delegate = try makeDelegate(permits: [0, 1, 1, 2])
        let result = SubtensorValidatorCoverage.make(
            hotkey: hotkey, delegates: [delegate],
            rows: [0, 1, 2, 3].map { SubtensorSubnetParametersTests.subnet(netuid: $0) }, blockHash: "hash"
        )
        XCTAssertEqual(result, .init(permitted: 2, total: 3, blockHash: "hash"))
    }

    func testUnknownAndIncompletePopulationsStayUnavailable() throws {
        let delegate = try makeDelegate(permits: [1])
        let subnet = SubtensorSubnetParametersTests.subnet()
        XCTAssertNil(SubtensorValidatorCoverage.make(hotkey: hotkey, delegates: [delegate], rows: [subnet, nil], blockHash: "x"))
        XCTAssertNil(SubtensorValidatorCoverage.make(hotkey: hotkey, delegates: [delegate], rows: [subnet, subnet], blockHash: "x"))
        XCTAssertNil(SubtensorValidatorCoverage.make(hotkey: hotkey, delegates: [delegate, delegate], rows: [subnet], blockHash: "x"))
        XCTAssertNil(SubtensorValidatorCoverage.make(hotkey: hotkey, delegates: [], rows: [subnet], blockHash: "x"))
        XCTAssertNil(SubtensorValidatorCoverage.make(hotkey: hotkey, delegates: [try makeDelegate(permits: [8])], rows: [subnet], blockHash: "x"))
    }

    func testCoverageOperationPinsBothReadsToBestBlock() throws {
        let api = MockSubtensorApiOperationFactoryProtocol()
        let delegate = try makeDelegate(permits: [1])
        stub(api) { stub in
            when(stub.createBestBlockHashWrapper()).thenReturn(.createWithResult("hash"))
            when(stub.createAllDynamicInfoWrapper(at: equal(to: "hash"))).thenReturn(.createWithResult([SubtensorSubnetParametersTests.subnet()]))
            when(stub.createDelegatesWrapper(at: equal(to: "hash"))).thenReturn(.createWithResult([delegate]))
        }
        let queue = OperationQueue()
        let wrapper = SubtensorValidatorCoverageFactory(apiFactory: api, operationQueue: queue).createWrapper(for: hotkey)
        let done = expectation(description: "coverage")
        wrapper.targetOperation.completionBlock = { done.fulfill() }
        queue.addOperations(wrapper.allOperations, waitUntilFinished: false)
        wait(for: [done], timeout: 10)
        XCTAssertEqual(try wrapper.targetOperation.extractNoCancellableResultData(), .init(permitted: 1, total: 1, blockHash: "hash"))
    }

    private func makeDelegate(permits: [UInt16]) throws -> SubtensorStakingPallet.DelegateInfo {
        let json: [String: Any] = [
            "delegateSs58": hotkey.base64EncodedString(), "ownerSs58": hotkey.base64EncodedString(),
            "take": "0", "nominators": [], "registrations": ["0", "99"],
            "validatorPermits": permits.map(String.init), "returnPer1000": "9999999", "totalDailyReturn": "99999999"
        ]
        return try JSONDecoder().decode(SubtensorStakingPallet.DelegateInfo.self, from: JSONSerialization.data(withJSONObject: json))
    }
}
