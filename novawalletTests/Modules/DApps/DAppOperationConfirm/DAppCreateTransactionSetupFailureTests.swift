import BigInt
import Cuckoo
import Foundation_iOS
@testable import novawallet
import SubstrateSdk
import XCTest

/// A request the wallet couldn't prepare must not leave a screen that explains nothing and does nothing.
final class DAppCreateTransactionSetupFailureTests: XCTestCase {
    typealias Setup = DAppCreateTransactionTestSetup

    func testSetupFailureOfWalletIsExplainedAndConfirmExplainsItAgain() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.westend()

        let setup = try Setup(
            runtime: runtime,
            fixture: DAppTxPayloadFixture.transfer(runtime: runtime),
            options: .init(
                metadataHashFactory: DAppFailingMetadataHashFactoryStub(
                    error: CommonMetadataShortenerError.metadataMissing
                )
            )
        )

        let alerts = AlertRecorder(expectedCount: 2)
        let feeStates = stubView(of: setup)

        stub(setup.wireframe) { stub in
            when(stub.present(viewModel: any(), style: any(), from: any())).then { viewModel, _, _ in
                alerts.record(viewModel)
            }
        }

        // when

        setup.presenter.setup()

        wait(for: [alerts.firstExpectation], timeout: 10)

        setup.presenter.confirm()

        // then

        wait(for: [alerts.allExpectation], timeout: 10)

        let expectedMessage = R.string(
            preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
        ).localizable.operationErrorMessage()

        XCTAssertEqual(alerts.viewModels.map(\.message), [expectedMessage, expectedMessage])
        XCTAssertEqual(feeStates.last, .empty)

        verify(setup.view, never()).didReceive(confirmationViewModel: any())
        verify(setup.delegate, never()).didReceiveConfirmationResponse(any(), for: any())
    }

    func testRequestThatFailedToSetUpCanStillBeRejected() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.westend()

        let setup = try Setup(
            runtime: runtime,
            fixture: DAppTxPayloadFixture.transfer(runtime: runtime),
            options: .init(metadataHashFactory: DAppFailingMetadataHashFactoryStub(error: CommonError.undefined))
        )

        let output = DAppOperationConfirmOutputSpy()
        setup.interactor.presenter = output
        setup.interactor.setup()

        wait(for: [output.modelExpectation], timeout: 10)

        // when

        setup.interactor.reject()

        // then

        wait(for: [output.responseExpectation], timeout: 10)

        let response = try XCTUnwrap(output.responseResults.last).get()

        XCTAssertNil(response.createTransactionResult)
        XCTAssertNil(response.signature)
    }

    func testConfirmBeforeSetupCompletesIsAnsweredAndSetupGoesOn() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.westend()
        let metadataHashFactory = DAppSuspendedMetadataHashFactoryStub()

        let setup = try Setup(
            runtime: runtime,
            fixture: DAppTxPayloadFixture.transfer(runtime: runtime),
            options: .init(metadataHashFactory: metadataHashFactory)
        )

        let output = DAppOperationConfirmOutputSpy()
        setup.interactor.presenter = output
        setup.interactor.setup()

        // when

        setup.interactor.confirm()

        // then

        guard
            case let .failure(error) = output.modelResults.last,
            case .requestNotPrepared(reason: nil) = error as? DAppOperationConfirmInteractorError else {
            XCTFail("The tap must be answered with the not prepared error")
            metadataHashFactory.release()
            return
        }

        XCTAssertTrue(output.responseResults.isEmpty)

        metadataHashFactory.release()

        wait(for: [output.feeExpectation], timeout: 10)

        XCTAssertNotNil(try? output.modelResults.last?.get())
        XCTAssertEqual(try output.feeResults.last?.get().value.amount, 1)
    }

    func testVerificationFailureFoundWithFeeStopsFeeLoading() throws {
        // given

        // a Vault wallet can't sign a general transaction, which is known once the extrinsic is built for the fee
        let runtime = try ExtrinsicGoldenRuntime.westendV16(customization: .init(formats: [5]))

        let setup = try Setup(
            runtime: runtime,
            fixture: DAppTxPayloadFixture.transfer(runtime: runtime),
            options: .init(walletType: .polkadotVault)
        )

        let alerts = AlertRecorder(expectedCount: 1)
        let feeStates = stubView(of: setup)

        stub(setup.wireframe) { stub in
            when(stub.present(viewModel: any(), style: any(), from: any())).then { viewModel, _, _ in
                alerts.record(viewModel)
            }
        }

        // when

        setup.presenter.setup()

        // then

        wait(for: [alerts.allExpectation], timeout: 10)

        let expectedMessage = R.string(
            preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
        ).localizable.dappConfirmationUnsupportedSigner()

        XCTAssertEqual(alerts.viewModels.map(\.message), [expectedMessage])
        XCTAssertEqual(feeStates.last, .empty)
    }

    func testFeeFailureOfNodeKeepsOfferingRetry() throws {
        // given

        let runtime = try ExtrinsicGoldenRuntime.westend()

        let setup = try Setup(
            runtime: runtime,
            fixture: DAppTxPayloadFixture.transfer(runtime: runtime),
            options: .init(nodeFee: 7, failingFeeQueries: 1)
        )

        let retryExpectation = XCTestExpectation()
        let loadedExpectation = XCTestExpectation()
        var retryAction: (() -> Void)?

        stub(setup.view) { stub in
            when(stub.didReceive(confirmationViewModel: any())).thenDoNothing()

            when(stub.didReceive(feeViewModel: any())).then { viewModel in
                if case .loaded = viewModel {
                    loadedExpectation.fulfill()
                }
            }
        }

        // the fee alert is the wireframe's own: Retry is its only action
        stub(setup.wireframe) { stub in
            when(stub.present(viewModel: any(), style: any(), from: any())).then { viewModel, _, _ in
                retryAction = viewModel.actions.first?.handler
                retryExpectation.fulfill()
            }
        }

        // when

        setup.presenter.setup()

        wait(for: [retryExpectation], timeout: 10)

        retryAction?()

        // then

        wait(for: [loadedExpectation], timeout: 10)
    }

    func testAlertOfVerificationFailureIsLocalizedAndKeepsDetailsOut() {
        let locale = Locale(identifier: "en")

        let unverified = R.string(preferredLanguages: locale.rLanguages).localizable
            .dappConfirmationUnverifiedTransaction()
        let unsupportedSigner = R.string(preferredLanguages: locale.rLanguages).localizable
            .dappConfirmationUnsupportedSigner()

        let details = "CheckNonce.extra <script>"

        let expectedMessages: [(DAppCreateTransactionError, String)] = [
            (.decodeError(details: details), unverified),
            (.invalidHex(details: details), unverified),
            (.missingMandatoryExtension(details: details), unverified),
            (.unsupportedTxExtensionVersion(details: details), unverified),
            (.signerUnavailable(details: details), unsupportedSigner)
        ]

        for (error, message) in expectedMessages {
            let content = error.toErrorContent(for: locale)

            XCTAssertEqual(content.message, message)
            XCTAssertFalse(content.message.contains(details))
            XCTAssertFalse(content.message.contains(error.name))

            // the dApp and the logs still get the technical text
            XCTAssertEqual(error.responseMessage, "\(error.name): \(details)")
        }

        XCTAssertNotEqual(unverified, unsupportedSigner)
        XCTAssertFalse(unverified.isEmpty)
        XCTAssertFalse(unsupportedSigner.isEmpty)
    }
}

private extension DAppCreateTransactionSetupFailureTests {
    final class FeeStates {
        enum State: Equatable {
            case loading
            case empty
            case loaded
        }

        private let lock = NSLock()
        private var states: [State] = []

        var last: State? {
            lock.lock()
            defer { lock.unlock() }

            return states.last
        }

        func append(_ state: State) {
            lock.lock()
            states.append(state)
            lock.unlock()
        }
    }

    final class AlertRecorder {
        let firstExpectation = XCTestExpectation(description: "first alert")
        let allExpectation = XCTestExpectation(description: "all alerts")

        private(set) var viewModels: [AlertPresentableViewModel] = []

        init(expectedCount: Int) {
            firstExpectation.assertForOverFulfill = false
            allExpectation.expectedFulfillmentCount = expectedCount
        }

        func record(_ viewModel: AlertPresentableViewModel) {
            viewModels.append(viewModel)
            firstExpectation.fulfill()
            allExpectation.fulfill()
        }
    }

    func stubView(of setup: Setup) -> FeeStates {
        let feeStates = FeeStates()

        stub(setup.view) { stub in
            when(stub.didReceive(confirmationViewModel: any())).thenDoNothing()

            when(stub.didReceive(feeViewModel: any())).then { viewModel in
                switch viewModel {
                case .loading:
                    feeStates.append(.loading)
                case .empty:
                    feeStates.append(.empty)
                case .loaded:
                    feeStates.append(.loaded)
                }
            }
        }

        return feeStates
    }
}
