import XCTest
@testable import novawallet
import SubstrateSdk

final class AssetHubSwapMatchingTests: XCTestCase {
    typealias Fixture = AssetHubHistoryFixture

    func testUnresolvedProxyCommissionCannotFallThroughToTransfer() throws {
        // given: the generic transfer matcher can decode the fee even without its transfer event
        let fixture = try Fixture()
        let call = try fixture.proxy(fixture.charged(receiver: Fixture.real), real: Fixture.real)
        let events = try [fixture.fee(), fixture.system()]
        let processor = ExtrinsicProcessor(accountId: Fixture.real, chain: fixture.chain)
        XCTAssertNotNil(try processor.matchBalancesTransfer(
            extrinsicIndex: 2, extrinsic: fixture.signed(call), eventRecords: fixture.records(events),
            metadata: fixture.codingFactory.metadata, context: fixture.context
        ))

        // when / then: recognized but unresolved commission owns the history disposition
        XCTAssertNil(try fixture.process(call, account: Fixture.real, events: events))
    }

    func testCollectionParsingErrorCannotFallThroughToTransfer() throws {
        let fixture = try Fixture()
        let call = try fixture.charged(receiver: Fixture.sender)
        let events = try [fixture.fee(), fixture.swapEvent(receiver: Fixture.sender), fixture.system()]
        XCTAssertNil(try fixture.process(call, account: Fixture.sender, events: events))
    }

    func testIncorrectCollectedAmountCannotFallThroughToTransfer() throws {
        let fixture = try Fixture()
        let call = try fixture.charged(receiver: Fixture.sender)
        let events = try [fixture.fee(), fixture.swapEvent(receiver: Fixture.sender),
                          fixture.transferEvent(sender: Fixture.sender, amount: "11"), fixture.system()]
        XCTAssertNil(try fixture.process(call, account: Fixture.sender, events: events))
    }

    func testSuccessfulDirectCommissionUsesMeasuredNetOutput() throws {
        let fixture = try Fixture()
        let result = try XCTUnwrap(fixture.process(
            fixture.charged(receiver: Fixture.sender), account: Fixture.sender,
            events: [fixture.fee(), fixture.swapEvent(receiver: Fixture.sender),
                     fixture.transferEvent(sender: Fixture.sender), fixture.system()]
        ))
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.swap?.amountIn, 1000)
        XCTAssertEqual(result.swap?.amountOut, 940)
        XCTAssertNil(result.amount)
    }

    func testNestedProxyFailureDoesNotRequireUndispatchedInnerMarker() throws {
        let fixture = try Fixture()
        let inner = try fixture.proxy(fixture.charged(receiver: Fixture.real), real: Fixture.real)
        let call = try fixture.proxy(inner, real: Fixture.other)
        let result = try XCTUnwrap(fixture.process(
            call, account: Fixture.real, events: [fixture.fee(), fixture.proxyEvent(success: false), fixture.system()]
        ))
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.swap?.amountOut, 890)
        XCTAssertNil(result.amount)
    }

    func testMultisigFailureDoesNotRequireUndispatchedProxyMarker() throws {
        let fixture = try Fixture()
        let inner = try fixture.proxy(fixture.charged(receiver: Fixture.real), real: Fixture.real)
        let call = try fixture.multisig(inner)
        let result = try XCTUnwrap(fixture.process(
            call, account: Fixture.real, events: [fixture.fee(), fixture.multisigEvent(
                call: inner, origin: multisigOrigin(), success: false
            ), fixture.system()]
        ))
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.swap?.amountOut, 890)
    }

    func testMultisigApprovalOnlyRemainsUnresolved() throws {
        let fixture = try Fixture()
        let origin = try multisigOrigin()
        let call = try fixture.multisig(fixture.charged(receiver: origin))
        XCTAssertNil(try fixture.process(call, account: origin, events: [fixture.fee(), fixture.system()]))
    }

    func testMultisigSuccessWithMissingProxyMarkerRemainsUnresolved() throws {
        let fixture = try Fixture()
        let inner = try fixture.proxy(fixture.charged(receiver: Fixture.real), real: Fixture.real)
        let call = try fixture.multisig(inner)
        let events = try [fixture.fee(), fixture.multisigEvent(call: inner, origin: multisigOrigin(), success: true),
                          fixture.system()]
        XCTAssertNil(try fixture.process(call, account: Fixture.real, events: events))
    }

    func testMultisigFailureWithWrongHashIsNotAttributed() throws {
        let fixture = try Fixture()
        let inner = try fixture.proxy(fixture.charged(receiver: Fixture.real), real: Fixture.real)
        let events = try [fixture.fee(), fixture.multisigEvent(
            call: inner, origin: multisigOrigin(), success: false, hash: Data(repeating: 0, count: 32)
        ), fixture.system()]
        XCTAssertNil(try fixture.process(fixture.multisig(inner), account: Fixture.real, events: events))
    }

    func testMultisigFailureWithWrongIdentityIsNotAttributed() throws {
        let fixture = try Fixture()
        let inner = try fixture.proxy(fixture.charged(receiver: Fixture.real), real: Fixture.real)
        for (origin, approver) in [(Fixture.real, Fixture.sender), (try multisigOrigin(), Fixture.other)] {
            let events = try [fixture.fee(), fixture.multisigEvent(
                call: inner, origin: origin, success: false, approver: approver
            ), fixture.system()]
            XCTAssertNil(try fixture.process(fixture.multisig(inner), account: Fixture.real, events: events))
        }
    }

    func testSuccessfulMultisigProxyChainRequiresOrderedCorrelatedMarkers() throws {
        let fixture = try Fixture()
        let inner = try fixture.proxy(fixture.charged(receiver: Fixture.real), real: Fixture.real)
        let proxyMarker = try fixture.proxyEvent(success: true)
        let multisigMarker = try fixture.multisigEvent(call: inner, origin: multisigOrigin(), success: true)
        let swapEvents = try [fixture.fee(), fixture.swapEvent(receiver: Fixture.real),
                              fixture.transferEvent(sender: Fixture.real)]
        let call = try fixture.multisig(inner)
        let result = try XCTUnwrap(fixture.process(
            call, account: Fixture.real, events: swapEvents + [proxyMarker, multisigMarker, fixture.system()]
        ))
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.swap?.amountOut, 940)
        XCTAssertNil(try fixture.process(
            call, account: Fixture.real, events: swapEvents + [multisigMarker, proxyMarker, fixture.system()]
        ))
    }

    func testDirectFailedBatchPreservesFailedSwapWithoutCollection() throws {
        let fixture = try Fixture()
        let result = try XCTUnwrap(fixture.process(
            fixture.charged(receiver: Fixture.sender), account: Fixture.sender,
            events: [fixture.fee(), fixture.system(success: false)]
        ))
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.swap?.amountOut, 890)
        XCTAssertNil(result.amount)
    }

    func testSuccessfulNestedProxiesUseInsideOutMarkers() throws {
        let fixture = try Fixture()
        let inner = try fixture.proxy(fixture.charged(receiver: Fixture.real), real: Fixture.real)
        let result = try XCTUnwrap(fixture.process(
            fixture.proxy(inner, real: Fixture.other), account: Fixture.real,
            events: [fixture.fee(), fixture.swapEvent(receiver: Fixture.real),
                     fixture.transferEvent(sender: Fixture.real), fixture.proxyEvent(success: true),
                     fixture.proxyEvent(success: true), fixture.system()]
        ))
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.swap?.amountOut, 940)
    }

    func testUnexpectedExtraProxyMarkersRemainUnresolved() throws {
        let fixture = try Fixture()
        let call = try fixture.proxy(fixture.charged(receiver: Fixture.real), real: Fixture.real)
        XCTAssertNil(try fixture.process(
            call, account: Fixture.real,
            events: [fixture.fee(), fixture.proxyEvent(success: false), fixture.proxyEvent(success: false), fixture.system()]
        ))
    }

    func testExtraProxyMarkersInMixedWrapperChainRemainUnresolved() throws {
        let fixture = try Fixture()
        let origin = try multisigOrigin()
        let inner = try fixture.multisig(fixture.charged(receiver: origin))
        let call = try fixture.proxy(inner, real: Fixture.sender)
        XCTAssertNil(try fixture.process(
            call, account: origin,
            events: [fixture.fee(), fixture.proxyEvent(success: false), fixture.proxyEvent(success: false), fixture.system()]
        ))
    }

    func testFailedUtilityChildCannotBorrowSuccessfulSiblingEvents() throws {
        let fixture = try Fixture()
        let call = try fixture.batch([
            fixture.charged(receiver: Fixture.sender), fixture.swap(receiver: Fixture.sender), fixture.collection()
        ], path: UtilityPallet.forceBatchPath)
        // The charged child rolled back. Only the standalone swap and donation emitted these events.
        let events = try [fixture.fee(), fixture.swapEvent(receiver: Fixture.sender),
                          fixture.transferEvent(sender: Fixture.sender), fixture.system()]
        XCTAssertNil(try fixture.process(call, account: Fixture.sender, events: events))
    }

    func testEveryAdditionalUtilityAncestorRemainsUnresolved() throws {
        let fixture = try Fixture()
        for path in [UtilityPallet.batchPath, UtilityPallet.batchAllPath, UtilityPallet.forceBatchPath] {
            let call = try fixture.batch([fixture.charged(receiver: Fixture.sender)], path: path)
            let events = try [fixture.fee(), fixture.swapEvent(receiver: Fixture.sender),
                              fixture.transferEvent(sender: Fixture.sender), fixture.system()]
            XCTAssertNil(try fixture.process(call, account: Fixture.sender, events: events))
        }
    }

    func testUtilityAncestorFlagSurvivesProxyWrapping() throws {
        let fixture = try Fixture()
        let call = try fixture.batch([
            fixture.proxy(fixture.charged(receiver: Fixture.real), real: Fixture.real)
        ], path: UtilityPallet.forceBatchPath)
        XCTAssertNil(try fixture.process(
            call, account: Fixture.real, events: [fixture.fee(), fixture.swapEvent(receiver: Fixture.real),
                                                  fixture.transferEvent(sender: Fixture.real), fixture.proxyEvent(success: true), fixture.system()]
        ))
    }

    func testUnrelatedStandaloneTransferStillFallsThrough() throws {
        let fixture = try Fixture()
        let result = try XCTUnwrap(fixture.process(
            fixture.collection(), account: Fixture.sender, events: [fixture.fee(), fixture.system()]
        ))
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.amount, 10)
        XCTAssertNil(result.swap)
    }

    func testEmptyBeneficiarySetPreservesGrossSwapHistory() throws {
        let fixture = try Fixture()
        let result = try XCTUnwrap(fixture.process(
            fixture.charged(receiver: Fixture.sender), account: Fixture.sender,
            events: [fixture.fee(), fixture.swapEvent(receiver: Fixture.sender), fixture.system()],
            beneficiaries: []
        ))
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.swap?.amountOut, 950)
    }

    func testCommissionedSwapWithoutFeeEventKeepsNetOutput() throws {
        let fixture = try Fixture()
        let result = try XCTUnwrap(fixture.process(
            fixture.charged(receiver: Fixture.sender), account: Fixture.sender,
            events: [fixture.swapEvent(receiver: Fixture.sender),
                     fixture.transferEvent(sender: Fixture.sender), fixture.system()]
        ))
        XCTAssertEqual(result.swap?.amountOut, 940)
        XCTAssertNil(result.fee)
    }

    func testTwentyByteMultisigSignatoryYieldsNoCommissionedBatch() throws {
        let fixture = try Fixture()
        let call = try fixture.multisig(fixture.charged(receiver: Fixture.sender))
        let batches = AssetHubCommissionTopology.findBatches(
            in: try call.toScaleCompatibleJSON(with: fixture.context.toRawContext()),
            extrinsicSender: AccountId(repeating: 1, count: 20),
            supportedAssetsPallets: PalletAssets.palletNames(for: fixture.chain),
            context: fixture.context
        )
        XCTAssertTrue(batches.isEmpty)
    }

    func testUnrecognizedBeneficiaryPreservesGrossSwapHistory() throws {
        let fixture = try Fixture()
        let call = try fixture.batch([fixture.swap(receiver: Fixture.sender), fixture.collection(beneficiary: Fixture.other)])
        let result = try XCTUnwrap(fixture.process(
            call, account: Fixture.sender,
            events: [fixture.fee(), fixture.swapEvent(receiver: Fixture.sender), fixture.system()]
        ))
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.swap?.amountOut, 950)
    }

    func testConfiguredBeneficiaryWithUndecodableSwapArgsRemainsUnresolved() throws {
        let fixture = try Fixture()
        let unreadableSwap = AnyRuntimeCall(
            moduleName: AssetConversionPallet.name,
            callName: AssetConversionPallet.swapExactTokenForTokensPath.callName,
            args: .dictionaryValue([:])
        )
        let extrinsic = try fixture.signed(fixture.batch([unreadableSwap, fixture.collection()]))
        let outcome = AssetHubCommissionHistoryParser().parse(
            extrinsic: extrinsic,
            sender: Fixture.sender,
            account: Fixture.sender,
            events: [],
            extrinsicSucceeded: true,
            chain: fixture.chain,
            codingFactory: fixture.codingFactory,
            beneficiaries: [Fixture.beneficiary]
        )

        guard case .recognizedButUnresolved = outcome else {
            return XCTFail("Expected a recognized but unresolved commission")
        }
    }

    func testThresholdOneSuccessWithAndWithoutExecutionMarker() throws {
        let fixture = try Fixture()
        let origin = try AssetHubCommissionTopology.deriveMultisigOrigin(
            sender: Fixture.sender, others: [Fixture.other], threshold: 1
        )
        let inner = try fixture.charged(receiver: origin)
        let call = try fixture.thresholdOne(inner)
        let swapEvents = try [fixture.fee(), fixture.swapEvent(receiver: origin), fixture.transferEvent(sender: origin)]
        for markers in [[], [try fixture.multisigEvent(call: inner, origin: origin, success: true)]] {
            let result = try XCTUnwrap(fixture.process(
                call, account: origin, events: swapEvents + markers + [fixture.system()]
            ))
            XCTAssertTrue(result.isSuccess)
            XCTAssertEqual(result.swap?.amountOut, 940)
        }
    }

    func testThresholdOneFailedDispatchPreservesFailedSwap() throws {
        let fixture = try Fixture()
        let origin = try AssetHubCommissionTopology.deriveMultisigOrigin(
            sender: Fixture.sender, others: [Fixture.other], threshold: 1
        )
        let result = try XCTUnwrap(fixture.process(
            fixture.thresholdOne(fixture.charged(receiver: origin)), account: origin,
            events: [fixture.fee(), fixture.system(success: false)]
        ))
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.swap?.amountOut, 890)
    }

    func testThresholdOneMustCheckInnerProxyResult() throws {
        let fixture = try Fixture()
        let inner = try fixture.proxy(fixture.charged(receiver: Fixture.real), real: Fixture.real)
        let result = try XCTUnwrap(fixture.process(
            fixture.thresholdOne(inner), account: Fixture.real,
            events: [fixture.fee(), fixture.proxyEvent(success: false), fixture.system()]
        ))
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.swap?.amountOut, 890)
    }

    func testThresholdOneDoesNotTurnInnerApprovalIntoExecution() throws {
        let fixture = try Fixture()
        let outerOrigin = try AssetHubCommissionTopology.deriveMultisigOrigin(
            sender: Fixture.sender, others: [Fixture.other], threshold: 1
        )
        let innerOrigin = try AssetHubCommissionTopology.deriveMultisigOrigin(
            sender: outerOrigin, others: [Fixture.other], threshold: 2
        )
        let inner = try fixture.multisig(fixture.charged(receiver: innerOrigin))
        XCTAssertNil(try fixture.process(
            fixture.thresholdOne(inner), account: innerOrigin, events: [fixture.fee(), fixture.system()]
        ))
    }

    func testThresholdOneMarkerWithWrongHashIsUnresolved() throws {
        let fixture = try Fixture()
        let origin = try AssetHubCommissionTopology.deriveMultisigOrigin(
            sender: Fixture.sender, others: [Fixture.other], threshold: 1
        )
        let inner = try fixture.charged(receiver: origin)
        XCTAssertNil(try fixture.process(
            fixture.thresholdOne(inner), account: origin,
            events: [fixture.fee(), fixture.swapEvent(receiver: origin), fixture.transferEvent(sender: origin),
                     fixture.multisigEvent(call: inner, origin: origin, success: true, hash: Data(repeating: 0, count: 32)),
                     fixture.system()]
        ))
    }

    func testEventMatcherUsesActualConfiguredCommissionPallet() throws {
        let fixture = try Fixture()
        let storage = AssetStorageInfo.statemine(info: .init(
            assetId: .stringValue("1984"), assetIdString: "1984", palletName: "ConfiguredAssets"
        ))
        let event = try fixture.event(PalletAssets.transferredPath(for: "ConfiguredAssets"))
        XCTAssertTrue(AssetConversionEventsMatching(commissionStorageInfo: storage).match(
            event: event, using: fixture.codingFactory
        ))
        XCTAssertFalse(AssetConversionEventsMatching().match(event: event, using: fixture.codingFactory))
    }
}

private extension AssetHubSwapMatchingTests {
    func multisigOrigin() throws -> AccountId {
        // Fixed SCALE tuple vector: domain + compact(2) + sorted 0x05/0x06 AccountIds + u16(2).
        // Computed independently with Python hashlib.blake2b(digest_size=32), not the production helper.
        try Data(hexString: "3da213910fcb48e71412f56acd17dc95f7a01177ee84c89e82fb00534f67a0b7")
    }
}
