import XCTest
import SoraKeystore
import BigInt
import IrohaCrypto
@testable import novawallet

class ExtrinsicServiceTests: XCTestCase {

    private func createExtrinsicBuilderClosure(amount: BigUInt) -> ExtrinsicBuilderClosure {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderClosure = { builder in
            let call = callFactory.bondExtra(amount: amount)
            _ = try builder.adding(call: call)
            return builder
        }

        return closure
    }

    private func createExtrinsicBuilderClosure(for batch: [PayoutInfo]) -> ExtrinsicBuilderClosure {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderClosure = { builder in
            try batch.forEach { payout in
                let payoutCall = try Staking.PayoutCall.V1(
                    validatorStash: payout.validator,
                    era: payout.era
                ).runtimeCall()
                
                _ = try builder.adding(call: payoutCall)
            }

            return builder
        }

        return closure
    }

    func testEstimateFeeForBondExtraCall() throws {
        let chainId = KnowChainId.kusama
        let selectedAddress = "FiLhWLARS32oxm4s64gmEMSppAdugsvaAx1pCjweTLGn5Rf"
        let assetPrecision: Int16 = 12

        let storageFacade = SubstrateStorageTestFacade()

        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        let connection = chainRegistry.getConnection(for: chainId)!
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!
        let chain = chainRegistry.getChain(for: chainId)!

        let senderResolutionFactory = try ExtrinsicSenderResolutionFactoryStub(address: selectedAddress, chain: chain)
        
        let extrinsicService = ExtrinsicService(
            chain: chain,
            runtimeRegistry: runtimeService,
            senderResolvingFactory: senderResolutionFactory,
            extensions: DefaultExtrinsicExtension.extensions(),
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )

        let feeExpectation = XCTestExpectation()
        let closure = createExtrinsicBuilderClosure(amount: 10)
        extrinsicService.estimateFee(closure, runningIn: .main) { result in
            switch result {
            case let .success(paymentInfo):
                if
                    let fee = Decimal.fromSubstrateAmount(paymentInfo.amount, precision: assetPrecision),
                    fee > 0 {
                    feeExpectation.fulfill()
                } else {
                    XCTFail("Cant parse fee")
                }
            case let .failure(error):
                XCTFail(error.localizedDescription)
            }
        }

        wait(for: [feeExpectation], timeout: 10)
    }

    func testEstimateFeeForPayoutRewardsCall() throws {
        let chainId = KnowChainId.kusama
        let selectedAddress = "FiLhWLARS32oxm4s64gmEMSppAdugsvaAx1pCjweTLGn5Rf"
        let selectedAccountId = try selectedAddress.toAccountId()
        let assetPrecision: Int16 = 12

        let storageFacade = SubstrateStorageTestFacade()

        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        let connection = chainRegistry.getConnection(for: chainId)!
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!
        let chain = chainRegistry.getChain(for: chainId)!
        
        let senderResolutionFactory = try ExtrinsicSenderResolutionFactoryStub(address: selectedAddress, chain: chain)

        let extrinsicService = ExtrinsicService(
            chain: chain,
            runtimeRegistry: runtimeService,
            senderResolvingFactory: senderResolutionFactory,
            extensions: DefaultExtrinsicExtension.extensions(),
            engine: connection,
            operationManager: OperationManagerFacade.sharedManager
        )

        let feeExpectation = XCTestExpectation()
        let payouts = [
            PayoutInfo(validator: selectedAccountId, era: 1000, pages: [0], reward: 100.0, identity: nil),
            PayoutInfo(validator: selectedAccountId, era: 1001, pages: [0], reward: 100.0, identity: nil),
            PayoutInfo(validator: selectedAccountId, era: 1002, pages: [0], reward: 100.0, identity: nil)
        ]
        let closure = createExtrinsicBuilderClosure(for: payouts)
        extrinsicService.estimateFee(closure, runningIn: .main) { result in
            switch result {
            case let .success(paymentInfo):
                if
                    let fee = Decimal.fromSubstrateAmount(paymentInfo.amount, precision: assetPrecision),
                    fee > 0 {
                    feeExpectation.fulfill()
                } else {
                    XCTFail("Cant parse fee")
                }
            case let .failure(error):
                XCTFail(error.localizedDescription)
            }
        }

        wait(for: [feeExpectation], timeout: 20)
    }

}
