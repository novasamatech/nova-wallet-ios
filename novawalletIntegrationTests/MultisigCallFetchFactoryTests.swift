import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class MultisigCallFetchFactoryTests: XCTestCase {
    func testPolkadotMultisigCallFetch() {
        /// as_multi call
        /// https://polkadot.subscan.io/multisig_extrinsic/24113414-3?call_hash=0xee73a78c700aea518d7cab7d7cb5fc4daf4c2abd1782aee8335ad54cf36b58ff
         
        let chainId = KnowChainId.polkadot
        let signatoryAccountAddress = "149AQApEw4Xe1DxWesqywiuGQHazbETMgWgT89WjEYFAc29y"
        let multisigAccountAddress = "13B84nmc8HGXjP4PGAsWS3Su945D3MVsbBddLvqdu8E9xq2o"
        let callHashHex = "0xee73a78c700aea518d7cab7d7cb5fc4daf4c2abd1782aee8335ad54cf36b58ff"
        let blockHashHex = "0xc6b386e537aee225da801c1552c25331440aa11f4c66a5fa47d2ff24d63691f8"
        
        let timePoint = MultisigPallet.EventTimePoint(
            height: 24113414,
            index: 3
        )
        let approvalEventModel = MultisigEvent.Approval(
            signatory: try! signatoryAccountAddress.toAccountId(),
            timepoint: timePoint
        )
        let eventType = MultisigEvent.EventType.approval(approvalEventModel)
        
        let event = MultisigEvent(
            accountId: try! multisigAccountAddress.toAccountId(),
            callHash: try! Data(hexString: callHashHex),
            extrinsicIndex: 3,
            eventType: eventType
        )
        
        do {
            try performFetchCallOrHashAndMatching(
                for: event,
                at: try! Data(hexString: blockHashHex),
                chainId: chainId,
                matching: try! Data(hexString: callHashHex)
            )
        } catch {
           XCTFail("Failed to perform fetch call or hash matching: \(error)")
        }
    }
    
    func performFetchCallOrHashAndMatching(
        for event: MultisigEvent,
        at blockHash: Data,
        chainId: ChainModel.Id,
        matching callHash: Substrate.CallHash
    ) throws {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let operationQueue = OperationQueue()
        
        let callFetchFactory = MultisigCallFetchFactory(chainRegistry: chainRegistry)
        
        let wrapper = callFetchFactory.createCallFetchWrapper(
            for: [event],
            at: blockHash,
            chainId: chainId
        )
        
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        
        let calls = try wrapper.targetOperation.extractNoCancellableResultData()
        let maybeCall = calls.first(where: { $0.key.callHash == callHash })?.value.call
        
        XCTAssert(maybeCall != nil, "Call should not be nil for the provided callHash")

        let foundCallHash = try maybeCall!.blake2b32()

        XCTAssert(callHash == foundCallHash, "Fetched call's hash should match the provided callHash")
    }
}

private enum MultisigCallFetchFactoryTestsErrors: Error {
    case callOrHashNotFound
}
