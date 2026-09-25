import BigInt
import Cuckoo
@testable import novawallet
import Operation_iOS
import SubstrateSdk
import XCTest

final class SubtensorStakingOperationServiceTests: XCTestCase {
    private let coldkey = Data(repeating: 0x11, count: 32)
    private let hotkey = Data(repeating: 0x22, count: 32)
    private let beneficiary = Data(repeating: 0xBB, count: 32)
    private let netuid: UInt16 = 64
    private let extrinsicHash = "0x" + String(repeating: "07", count: 32)
    private let blockHash = "0x" + String(repeating: "08", count: 32)

    private var sellOperation: SubtensorStakingOperation {
        .subnetSell(hotkey: hotkey, netuid: netuid, alpha: 500_000_000_000, limitPrice: 7_644_839)
    }

    func testSuccessfulSellReturnsOutcomeThenRefreshesPositionsAndPostsStakingChanged() throws {
        let removedHex = "0703" + coldkey.toHex() + hotkey.toHex() + le(UInt64(3_840_000_000)) +
            le(UInt64(500_000_000_000)) + le(netuid) + le(UInt64(250_000_000))
        let feeTransferHex = "0502" + coldkey.toHex() + beneficiary.toHex() + le(UInt64(11_467_258))

        let events = try decodeEvents([removedHex, feeTransferHex])
        let context = try makeContext(status: .success(.init(
            extrinsicHash: extrinsicHash,
            blockHash: blockHash,
            interestedEvents: events
        )))

        stubRefreshAndNotify(context)

        let outcome = try run(context.service.createSubmitWrapper(for: sellOperation)).get()

        let expected = SubtensorStakingOperationOutcome(
            executed: SubtensorExecutedAmounts(tao: 3_840_000_000, alpha: 500_000_000_000, netuid: netuid),
            claimedTao: nil,
            novaFeePaid: 11_467_258,
            alphaFeePaid: nil,
            extrinsicHash: extrinsicHash
        )

        let eventCaptor = ArgumentCaptor<EventProtocol>()

        XCTAssertEqual(outcome, expected)
        XCTAssertEqual(context.sharedOperation.status, .sent)
        verify(context.positionsSyncService, times(1)).refresh()
        verify(context.eventCenter, times(1)).notify(with: eventCaptor.capture())

        let changed = try XCTUnwrap(eventCaptor.value as? SubtensorStakingChanged)

        XCTAssertEqual(changed.chainAssetId, context.chainAsset.chainAssetId)
        XCTAssertEqual(changed.accountId, coldkey)
    }

    func testDispatchFailureIsMappedWithoutRefreshOrStakingChanged() throws {
        let dispatchError = DispatchCallError.module(
            .init(
                raw: .init(moduleIndex: 7, error: Data(repeating: 0, count: 4)),
                display: .init(moduleName: "SubtensorModule", errorName: "SlippageTooHigh")
            )
        )

        let context = try makeContext(status: .failure(.init(
            extrinsicHash: extrinsicHash,
            blockHash: blockHash,
            error: dispatchError
        )))

        stubRefreshAndNotify(context)

        let result = run(context.service.createSubmitWrapper(for: sellOperation))

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? SubtensorStakingSubmissionError, .slippageTooHigh)
        }

        XCTAssertEqual(context.sharedOperation.status, .composing)
        verify(context.positionsSyncService, never()).refresh()
        verify(context.eventCenter, never()).notify(with: any())
    }

    func testSubnetSellWithoutBeneficiaryFailsBeforeSubmission() throws {
        let context = try makeContext(
            status: .success(.init(extrinsicHash: extrinsicHash, blockHash: blockHash, interestedEvents: [])),
            beneficiary: nil
        )

        stubRefreshAndNotify(context)

        let result = run(context.service.createSubmitWrapper(for: sellOperation))

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? SubtensorStakingOperationError, .novaFeeUnavailable)
        }

        XCTAssertEqual(context.sharedOperation.status, .composing)
        verify(context.positionsSyncService, never()).refresh()
    }

    func testFeeWrapperReturnsTheEstimatedNetworkFee() throws {
        let context = try makeContext(
            status: .success(.init(extrinsicHash: extrinsicHash, blockHash: blockHash, interestedEvents: []))
        )

        let fee = try run(context.service.createFeeWrapper(for: sellOperation)).get()

        XCTAssertEqual(fee.amount, 734_304)
    }

    private struct Context {
        let chainAsset: ChainAsset
        let service: SubtensorStakingOperationService
        let positionsSyncService: MockSubtensorPositionsSyncServiceProtocol
        let eventCenter: MockEventCenterProtocol
        let sharedOperation: SharedOperation
    }

    private func makeContext(
        status: SubstrateExtrinsicStatus,
        beneficiary: AccountId? = Data(repeating: 0xBB, count: 32)
    ) throws -> Context {
        let chainAsset = makeChainAsset()
        let positionsSyncService = MockSubtensorPositionsSyncServiceProtocol()
        let eventCenter = MockEventCenterProtocol()
        let sharedOperation = SharedOperation()

        let chainAccount = AccountGenerator.generateSubstrateChainAccountResponse(for: KnowChainId.bittensor)
        let submission = ExtrinsicMonitorSubmission(
            extrinsicSubmittedModel: ExtrinsicSubmittedModel(txHash: extrinsicHash, sender: .current(chainAccount)),
            status: status
        )

        let networkFee = ExtrinsicFee(amount: 734_304, payer: nil, weight: .zero)

        let service = try SubtensorStakingOperationService(
            chainAsset: chainAsset,
            accountId: coldkey,
            extrinsicService: ExtrinsicServiceStub(
                feeResult: .success(networkFee),
                submittedModelResult: .success(submission.extrinsicSubmittedModel)
            ),
            extrinsicSubmitMonitor: ExtrinsicSubmitMonitorFactoryStub(submission: submission),
            signer: DummySigner(cryptoType: .sr25519),
            runtimeProvider: RuntimeCodingServiceStub(factory: RuntimeCodingServiceStub.createBittensorCodingFactory()),
            positionsSyncService: positionsSyncService,
            sharedOperation: sharedOperation,
            eventCenter: eventCenter,
            feeCalculator: SubtensorNovaFeeCalculator(beneficiary: beneficiary)
        )

        return Context(
            chainAsset: chainAsset,
            service: service,
            positionsSyncService: positionsSyncService,
            eventCenter: eventCenter,
            sharedOperation: sharedOperation
        )
    }

    private func stubRefreshAndNotify(_ context: Context) {
        stub(context.positionsSyncService) { stub in
            when(stub.refresh()).thenDoNothing()
        }

        stub(context.eventCenter) { stub in
            when(stub.notify(with: any())).thenDoNothing()
        }
    }

    private func makeChainAsset() -> ChainAsset {
        let asset = AssetModel(
            assetId: AssetModel.utilityAssetId,
            icon: nil,
            name: "Bittensor",
            symbol: "TAO",
            precision: 9,
            priceId: nil,
            stakings: [.subtensor],
            type: nil,
            typeExtras: nil,
            buyProviders: nil,
            sellProviders: nil,
            source: .remote
        )

        let chain = ChainModelGenerator.generateChain(
            assets: [asset],
            defaultChainId: KnowChainId.bittensor,
            addressPrefix: 42
        )

        return ChainAsset(chain: chain, asset: asset)
    }

    private func decodeEvents(_ eventsHex: [String]) throws -> [Event] {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()
        let entry = try XCTUnwrap(codingFactory.metadata.getStorageMetadata(for: SystemPallet.eventsPath))

        let recordsHex = le(UInt8(eventsHex.count << 2)) + eventsHex.map { "00" + "00000000" + $0 + "00" }.joined()
        let decoder = try codingFactory.createDecoder(from: Data(hexString: recordsHex))
        let json = try decoder.read(type: entry.type.typeName)

        return try json.map(
            to: [EventRecord].self,
            with: codingFactory.createRuntimeJsonContext().toRawContext()
        ).map(\.event)
    }

    private func le<T: FixedWidthInteger>(_ value: T) -> String {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }.toHex()
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) -> Result<T, Error> {
        let completed = expectation(description: "wrapper completed")

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                completed.fulfill()
            }
        }

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: false)

        wait(for: [completed], timeout: 10)

        return Result { try wrapper.targetOperation.extractNoCancellableResultData() }
    }
}
