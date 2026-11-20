import BigInt
import Cuckoo
@testable import novawallet
import SubstrateSdk
import XCTest

/// The fee row must show everything the signed transaction pays: the node quotes the fee without the tip,
/// and the tip comes with the payment extension of the dApp.
final class DAppCreateTransactionFeeTests: XCTestCase {
    private typealias ExtensionId = Extrinsic.TransactionExtensionId
    private typealias PaymentFixture = DAppTxPayloadPaymentFixture
    typealias Setup = DAppCreateTransactionTestSetup

    private static let nodeFee = BigUInt(10)

    func testFeeWithoutTipIsTheOneOfNode() throws {
        let westend = try ExtrinsicGoldenRuntime.westend()
        let assetHub = try ExtrinsicGoldenRuntime.polkadotAssetHub()

        let westendSetup = try Setup(
            runtime: westend,
            fixture: DAppTxPayloadFixture.transfer(runtime: westend),
            options: .init(nodeFee: Self.nodeFee)
        )

        let assetHubSetup = try Setup(
            runtime: assetHub,
            fixture: DAppTxPayloadFixture.transfer(runtime: assetHub),
            options: .init(chain: PaymentFixture.makeAssetHubChain(), nodeFee: Self.nodeFee)
        )

        XCTAssertEqual(try loadConfirmation(of: westendSetup).fee, 10)
        XCTAssertEqual(try loadConfirmation(of: assetHubSetup).fee, 10)
    }

    func testTipOfAssetPaymentIsAddedToNativeFee() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
            .replacing(ExtensionId.assetTxPayment, extra: PaymentFixture.assetPayment(tip: 3))

        let setup = try Setup(
            runtime: runtime,
            fixture: fixture,
            options: .init(chain: PaymentFixture.makeAssetHubChain(), nodeFee: Self.nodeFee)
        )

        // when

        let confirmation = try loadConfirmation(of: setup)

        // then

        XCTAssertNil(confirmation.feeAsset)
        XCTAssertEqual(confirmation.fee, 13)
    }

    func testTipOfAssetPaymentIsConvertedToFeeAssetTogetherWithFee() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let payment = try PaymentFixture.assetPayment(tip: 3, assetLocation: PaymentFixture.usdtLocation)
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
            .replacing(ExtensionId.assetTxPayment, extra: payment)

        let setup = try Setup(
            runtime: runtime,
            fixture: fixture,
            options: .init(chain: PaymentFixture.makeAssetHubChain(), nodeFee: Self.nodeFee, feeAssetRate: 2)
        )

        // when

        let confirmation = try loadConfirmation(of: setup)

        // then

        // the runtime swaps the asset for the fee and the tip at once: (10 + 3) units of the native token
        XCTAssertEqual(confirmation.feeAsset?.asset.symbol, PaymentFixture.usdtSymbol)
        XCTAssertEqual(confirmation.fee, 26)
    }

    func testTipOfTransactionPaymentIsAddedOnce() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.westend()

        var values = DAppTxPayloadFixture.Values()
        values.tip = 5

        let setup = try Setup(
            runtime: runtime,
            fixture: DAppTxPayloadFixture.transfer(runtime: runtime, values: values),
            options: .init(nodeFee: Self.nodeFee)
        )

        // when

        let confirmation = try loadConfirmation(of: setup)

        // then

        XCTAssertNil(confirmation.feeAsset)
        XCTAssertEqual(confirmation.fee, 15)
    }

    func testTipOfGeneralTransactionIsAdded() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.westendV16(customization: .init(formats: [5]))

        var values = DAppTxPayloadFixture.Values()
        values.tip = 5

        let setup = try Setup(
            runtime: runtime,
            fixture: DAppTxPayloadFixture.transfer(runtime: runtime, values: values),
            options: .init(nodeFee: Self.nodeFee)
        )

        // when

        let confirmation = try loadConfirmation(of: setup)

        // then

        XCTAssertEqual(confirmation.fee, 15)
    }

    func testShownTipIsTheSignedOne() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
            .replacing(ExtensionId.assetTxPayment, extra: PaymentFixture.assetPayment(tip: 3))

        let setup = try Setup(
            runtime: runtime,
            fixture: fixture,
            options: .init(chain: PaymentFixture.makeAssetHubChain(), nodeFee: Self.nodeFee)
        )

        let output = DAppOperationConfirmOutputSpy()
        setup.interactor.presenter = output
        setup.interactor.setup()

        wait(for: [output.modelExpectation, output.feeExpectation], timeout: 10)

        // when

        setup.interactor.confirm()

        wait(for: [output.responseExpectation], timeout: 10)

        // then

        guard case let .success(response) = output.responseResults.last,
              case let .success(extrinsicData) = response.createTransactionResult else {
            XCTFail("Signed extrinsic expected")
            return
        }

        let signed = try XCTUnwrap(
            runtime.decodeExtrinsic(extrinsicData.toHex(includePrefix: true)).getSignedExtrinsic()
        )

        XCTAssertEqual(try DAppTxPayloadPaymentResolver.totalTip(in: signed.signature.extra), 3)
    }

    func testFeeRowNamesTheAssetTheFeeIsPaidIn() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let payment = try PaymentFixture.assetPayment(tip: 3000, assetLocation: PaymentFixture.usdtLocation)
        let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
            .replacing(ExtensionId.assetTxPayment, extra: payment)

        let setup = try Setup(
            runtime: runtime,
            fixture: fixture,
            options: .init(chain: PaymentFixture.makeAssetHubChain(), nodeFee: 10000, feeAssetRate: 2)
        )

        let feeExpectation = XCTestExpectation()
        var shownAmount: String?

        stub(setup.view) { stub in
            when(stub.didReceive(confirmationViewModel: any())).thenDoNothing()

            when(stub.didReceive(feeViewModel: any())).then { viewModel in
                if case let .loaded(value) = viewModel {
                    shownAmount = value?.amount
                    feeExpectation.fulfill()
                }
            }
        }

        // when

        setup.presenter.setup()

        // then

        wait(for: [feeExpectation], timeout: 10)

        // (10 000 + 3 000) * 2 units of an asset with 6 decimals
        XCTAssertEqual(shownAmount, "0.026 USDT")
    }

    func testPaymentInAssetTheWalletCantMatchIsRefused() throws {
        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()

        let unlisted = try PaymentFixture.assetPayment(tip: 0, assetLocation: PaymentFixture.unlistedAssetLocation)
        let listed = try PaymentFixture.assetPayment(tip: 0, assetLocation: PaymentFixture.usdtLocation)

        let cases: [(payment: Data, chain: ChainModel)] = [
            (unlisted, try PaymentFixture.makeAssetHubChain()),
            (listed, try ExtrinsicGoldenRuntime.makeChain())
        ]

        for (payment, chain) in cases {
            // given

            let fixture = try DAppTxPayloadFixture.transfer(runtime: runtime)
                .replacing(ExtensionId.assetTxPayment, extra: payment)

            let setup = try Setup(
                runtime: runtime,
                fixture: fixture,
                options: .init(chain: chain, nodeFee: Self.nodeFee)
            )

            let output = DAppOperationConfirmOutputSpy()
            setup.interactor.presenter = output

            // when

            setup.interactor.setup()

            wait(for: [output.modelExpectation], timeout: 10)

            setup.interactor.confirm()

            wait(for: [output.responseExpectation], timeout: 10)

            // then

            guard case let .failure(modelError) = output.modelResults.last else {
                XCTFail("The confirmation must not load")
                return
            }

            XCTAssertEqual((modelError as? DAppCreateTransactionError)?.name, "DecodeError")

            guard case let .success(response) = output.responseResults.last,
                  case let .failure(error) = response.createTransactionResult else {
                XCTFail("The dApp must get the failure")
                return
            }

            XCTAssertEqual(error.name, "DecodeError")
            XCTAssertTrue(error.details.contains(ExtensionId.assetTxPayment), error.details)

            // a fee in the native token is never shown for such a payload
            XCTAssertTrue(output.feeResults.allSatisfy { (try? $0.get().value.amount) == 0 })
        }
    }

    func testProductionRegistryConvertsTheFeeThatIncludesTip() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
        let chain = try PaymentFixture.makeAssetHubChain()
        let setup = try Setup(
            runtime: runtime,
            fixture: DAppTxPayloadFixture.transfer(runtime: runtime),
            options: .init(chain: chain)
        )

        let usdt = try XCTUnwrap(chain.chainAssets().first { !$0.asset.isUtility })

        // when

        let registry = try XCTUnwrap(setup.interactor.feeOperationFactory as? ExtrinsicProxyOperationFactory)
            .feeEstimationRegistry as? ExtrinsicFeeEstimationRegistry

        let wrapperFactory = try XCTUnwrap(
            registry?.estimatingWrapperFactory as? ExtrinsicFeeEstimatingWrapperFactory
        )

        let conversionEstimator = try XCTUnwrap(
            wrapperFactory.customFeeEstimatorFactory.createCustomFeeEstimator(
                for: usdt
            ) as? ExtrinsicAssetConversionFeeEstimator
        )

        // then

        XCTAssertTrue(wrapperFactory.nativeFeeEstimator is DAppTxPayloadFeeEstimator)
        XCTAssertTrue(conversionEstimator.nativeFeeEstimator is DAppTxPayloadFeeEstimator)
        XCTAssertTrue(wrapperFactory.customFeeEstimatorFactory is AssetConversionFeeEstimatingFactory)
    }
}

private extension DAppCreateTransactionFeeTests {
    struct Confirmation {
        let feeAsset: ChainAsset?
        let fee: BigUInt
    }

    /// What the interactor hands to the presenter once the payload is verified and the fee is estimated.
    func loadConfirmation(of setup: Setup) throws -> Confirmation {
        let output = DAppOperationConfirmOutputSpy()
        setup.interactor.presenter = output

        setup.interactor.setup()

        wait(for: [output.modelExpectation, output.feeExpectation], timeout: 10)

        XCTAssertEqual(output.modelResults.count, 1)
        XCTAssertEqual(output.feeResults.count, 1)

        let model = try XCTUnwrap(output.modelResults.first).get()
        let fee = try XCTUnwrap(output.feeResults.first).get()

        return Confirmation(feeAsset: model.feeAsset, fee: fee.value.amount)
    }
}
