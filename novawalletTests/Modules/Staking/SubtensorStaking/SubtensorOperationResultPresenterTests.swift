import Cuckoo
import Foundation_iOS
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorOperationResultPresenterTests: XCTestCase {
    struct Setup {
        let presenter: SubtensorOperationResultPresenter
        let view: MockSubtensorResultViewProtocol
        let wireframe: MockSubtensorResultWireframeProtocol
        let delegate: MockSubtensorOperationResultDelegate
    }

    func testNinetySecondsWithoutAResultShowsUnconfirmedAndALateSuccessShowsDone() throws {
        let service = MockSubtensorStakingOperationServiceProtocol()
        let scheduler = MockSchedulerProtocol()
        let submissionStarted = expectation(description: "Submission started")
        let capScheduled = expectation(description: "Confirmation cap scheduled")
        let unconfirmedShown = expectation(description: "Unconfirmed shown")
        let doneShown = expectation(description: "Done shown")
        var completeSubmission: ((Result<SubtensorStakingOperationOutcome, Error>) -> Void)?

        let submitOperation = AsyncClosureOperation<SubtensorStakingOperationOutcome> { completion in
            completeSubmission = completion
            submissionStarted.fulfill()
        }

        stub(service) { stub in
            when(stub.createSubmitWrapper(for: any())).thenReturn(CompoundOperationWrapper(targetOperation: submitOperation))
        }

        stub(scheduler) { stub in
            when(stub.notifyAfter(any())).then { _ in capScheduled.fulfill() }
            when(stub.cancel()).thenDoNothing()
        }

        let view = MockSubtensorResultViewProtocol()
        var statuses: [SubtensorResultStatus] = []
        var unconfirmedActions: [SubtensorResultAction?] = []

        stub(view) { stub in
            when(stub.didUpdateCountdown(remainedTime: any())).thenDoNothing()
            when(stub.didReceive(viewModel: any())).then { viewModel in
                guard case let .page(page) = viewModel else {
                    return
                }

                statuses.append(page.status.status)

                if page.status.status == .pending {
                    unconfirmedActions.append(page.action?.action)
                    unconfirmedShown.fulfill()
                } else if page.status.status == .done {
                    doneShown.fulfill()
                }
            }
        }

        let interactor = makeInteractor(service: service, scheduler: scheduler)
        let presenter = makePresenter(interactor: interactor, view: view).presenter
        interactor.presenter = presenter

        presenter.setup()
        wait(for: [submissionStarted, capScheduled], timeout: 10)

        interactor.didTrigger(scheduler: scheduler)
        wait(for: [unconfirmedShown], timeout: 10)

        completeSubmission?(.success(makeOutcome()))
        wait(for: [doneShown], timeout: 10)

        verify(scheduler).notifyAfter(SubtensorOperationResultConstants.confirmationCap)
        XCTAssertEqual(statuses.first, .progress)
        XCTAssertEqual(statuses.last, .done)
        XCTAssertEqual(unconfirmedActions, [.done])
    }

    func testNotSubmittedFailureSaysNothingWasSpent() throws {
        let strings = R.string(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages).localizable
        let setup = makePresenter(interactor: makeMockInteractor())
        var details: String?

        stubStatusDetails(on: setup.view) { details = $0 }

        setup.presenter.didReceiveSubmission(
            result: .failure(
                SubtensorStakingSubmissionFailure(
                    stage: .notSubmitted,
                    error: SubtensorStakingSubmissionError.feeUnpayable
                )
            )
        )

        let text = try XCTUnwrap(details)
        XCTAssertTrue(text.hasSuffix(strings.stakingSubtensorResultNothingSpent()))
        XCTAssertFalse(text.contains(strings.stakingSubtensorResultFeeCharged()))
    }

    func testDispatchedFailureSaysOnlyTheNetworkFeeWasCharged() throws {
        let strings = R.string(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages).localizable
        let setup = makePresenter(interactor: makeMockInteractor())
        var details: String?

        stubStatusDetails(on: setup.view) { details = $0 }

        setup.presenter.didReceiveSubmission(
            result: .failure(
                SubtensorStakingSubmissionFailure(
                    stage: .dispatched(blockHash: "0x01", extrinsicHash: "0x02"),
                    error: SubtensorStakingSubmissionError.slippageTooHigh
                )
            )
        )

        let text = try XCTUnwrap(details)
        XCTAssertTrue(text.hasPrefix(strings.stakingSubtensorResultFailedPriceMovedFormat("0.5%")))
        XCTAssertTrue(text.hasSuffix(strings.stakingSubtensorResultFeeCharged()))
        XCTAssertFalse(text.contains(strings.stakingSubtensorResultNothingSpent()))
    }

    func testSigningCancelledClosesTheResultAndRequestsRetry() {
        let setup = makePresenter(interactor: makeMockInteractor())

        stub(setup.view) { stub in
            when(stub.didReceive(viewModel: any())).thenDoNothing()
            when(stub.didUpdateCountdown(remainedTime: any())).thenDoNothing()
        }

        stub(setup.wireframe) { stub in
            when(stub.closeForRetry(from: any(), completion: any())).then { _, completion in completion() }
        }

        stub(setup.delegate) { stub in
            when(stub.didRequestRetry()).thenDoNothing()
        }

        setup.presenter.didReceiveSubmission(
            result: .failure(
                SubtensorStakingSubmissionFailure(stage: .notSubmitted, error: HardwareSigningError.signingCancelled)
            )
        )

        verify(setup.wireframe).closeForRetry(from: any(), completion: any())
        verify(setup.delegate).didRequestRetry()
        verify(setup.view, never()).didReceive(viewModel: any())
    }

    func testRootAddStakeDoneShowsStakeAfterFromGroupTotalPlusExecuted() throws {
        let strings = R.string(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages).localizable
        let request = makeRequest(
            operation: .rootStake(hotkey: hotkey, amount: 5_000_000_000),
            origin: .addStake,
            target: .root,
            stakeBefore: 20_000_000_000,
            groupHotkeyCount: 1
        )

        let setup = makePresenter(interactor: makeMockInteractor(), request: request)
        var sheet: SubtensorResultSheetViewModel?

        stub(setup.view) { stub in
            when(stub.didUpdateCountdown(remainedTime: any())).thenDoNothing()
            when(stub.didReceive(viewModel: any())).then { viewModel in
                if case let .sheet(sheetViewModel) = viewModel {
                    sheet = sheetViewModel
                }
            }
        }

        setup.presenter.didReceiveSubmission(
            result: .success(makeOutcome(executed: SubtensorExecutedAmounts(tao: 5_000_000_000, alpha: 5_000_000_000, netuid: 0)))
        )

        let doneSheet = try XCTUnwrap(sheet)
        XCTAssertEqual(doneSheet.message, strings.stakingSubtensorResultRootStakeNowWithFormat("25 TAO", "Nova Wallet"))
        XCTAssertEqual(doneSheet.rows.first?.value, "25 TAO")
        XCTAssertEqual(doneSheet.actions.map(\.action), [.yourBittensor, .backToPosition])
    }

    func testSellDoneShowsTaoNetOfNovaFeeAndReturnsToPosition() throws {
        let request = makeRequest(
            operation: .subnetSell(
                hotkey: hotkey,
                netuid: 64,
                alpha: 56_200_000_000,
                limitPrice: 70_000_000,
                quotedTaoOut: 4_145_000_000
            ),
            origin: .sell,
            groupHotkeyCount: 1
        )

        let setup = makePresenter(interactor: makeMockInteractor(), request: request)
        var page: SubtensorResultPageViewModel?

        stub(setup.view) { stub in
            when(stub.didUpdateCountdown(remainedTime: any())).thenDoNothing()
            when(stub.didReceive(viewModel: any())).then { viewModel in
                if case let .page(pageViewModel) = viewModel {
                    page = pageViewModel
                }
            }
        }

        stub(setup.wireframe) { stub in
            when(stub.closeOperation(from: any())).thenDoNothing()
        }

        setup.presenter.didReceiveSubmission(
            result: .success(
                makeOutcome(
                    executed: SubtensorExecutedAmounts(tao: 4_145_000_000, alpha: 56_200_000_000, netuid: 64),
                    novaFeePaid: 35_000_000
                )
            )
        )

        setup.presenter.activate(action: .done)

        let donePage = try XCTUnwrap(page)
        XCTAssertEqual(donePage.payTile.amount, "56.2 SN64")
        XCTAssertEqual(donePage.receiveTile.amount, "≈ 4.11 TAO")
        verify(setup.wireframe).closeOperation(from: any())
    }
}

private extension SubtensorOperationResultPresenterTests {
    var hotkey: AccountId {
        Data(repeating: 7, count: 32)
    }

    var subnetTarget: SubtensorStakeTarget {
        let info = SubtensorFlowChainWorld.dynamicInfo(
            netuid: 64,
            name: "Chutes",
            symbol: "CH",
            registeredAt: 1,
            tempo: 360
        )

        return .subnet(info: info, price: 73_800_000)
    }

    func makeRequest(
        operation: SubtensorStakingOperation? = nil,
        origin: SubtensorOperationOrigin = .newPosition,
        target: SubtensorStakeTarget? = nil,
        stakeBefore: Balance = 0,
        groupHotkeyCount: Int = 0
    ) -> SubtensorOperationResultRequest {
        SubtensorOperationResultRequest(
            operation: operation ?? .subnetBuy(hotkey: hotkey, netuid: 64, grossTao: 5_000_000_000, limitPrice: 74_169_000),
            origin: origin,
            account: SubtensorFlowChainWorld.coldkeyAccount(),
            target: target ?? subnetTarget,
            payAmount: 5_000_000_000,
            quote: nil,
            slippage: target?.isRoot == true ? nil : BigRational(numerator: 5, denominator: 1000),
            validator: SubtensorConfirmValidator(
                hotkey: hotkey,
                display: DisplayAddress(address: "5FNova", username: "Nova Wallet"),
                annualRate: nil
            ),
            estimatedNetworkFee: ExtrinsicFee(amount: 1_500_000, payer: nil, weight: .init(refTime: 1000, proofSize: 0)),
            stakeBefore: stakeBefore,
            groupHotkeyCount: groupHotkeyCount,
            emptiesPosition: false,
            prices: SubtensorOperationResultPrices(taoPrice: nil, alphaSpot: 73_800_000)
        )
    }

    func makeOutcome(
        executed: SubtensorExecutedAmounts = SubtensorExecutedAmounts(tao: 4_957_861_000, alpha: 67_180_000_000, netuid: 64),
        novaFeePaid: Balance? = 42_139_000
    ) -> SubtensorStakingOperationOutcome {
        SubtensorStakingOperationOutcome(
            executed: executed,
            novaFeePaid: novaFeePaid,
            alphaFeePaid: nil,
            networkFeePaid: 1_500_000,
            extrinsicHash: "0x02",
            blockHash: "0x01"
        )
    }

    func makeInteractor(
        service: MockSubtensorStakingOperationServiceProtocol,
        scheduler: MockSchedulerProtocol
    ) -> SubtensorOperationResultInteractor {
        let chainFactory = MockSubtensorResultChainFactoryProtocol()
        let catalogueService = MockSubtensorSubnetCatalogueServiceProtocol()
        let earnConfigProvider = MockSubtensorEarnConfigProviderProtocol()

        stub(chainFactory) { stub in
            when(stub.createExpectedBlockTimeWrapper()).thenReturn(.createWithResult(12000))
            when(stub.createBlockTimestampWrapper(at: any())).thenReturn(
                .createWithError(BaseOperationError.unexpectedDependentResult)
            )
        }

        stub(catalogueService) { stub in
            when(stub.createCatalogueWrapper(forcingRefresh: any())).thenReturn(
                .createWithError(BaseOperationError.unexpectedDependentResult)
            )
        }

        stub(earnConfigProvider) { stub in
            when(stub.createConfigWrapper()).thenReturn(.createWithError(BaseOperationError.unexpectedDependentResult))
        }

        return SubtensorOperationResultInteractor(
            operation: makeRequest().operation,
            coldkey: SubtensorFlowChainWorld.coldkey,
            loadsSubnetData: true,
            operationService: service,
            chainFactory: chainFactory,
            catalogueService: catalogueService,
            earnConfigProvider: earnConfigProvider,
            positionsSyncService: nil,
            osMediator: OperatingSystemMediator(),
            applicationHandler: ApplicationHandler(),
            schedulerFactory: { _ in scheduler },
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    func makeMockInteractor() -> MockSubtensorResultInteractorInputProtocol {
        let interactor = MockSubtensorResultInteractorInputProtocol()

        stub(interactor) { stub in
            when(stub.setup()).thenDoNothing()
            when(stub.fetchBlockTimestamp(at: any())).thenDoNothing()
            when(stub.fetchRootHoldRemainingBlocks(for: any())).thenDoNothing()
        }

        return interactor
    }

    func makePresenter(
        interactor: SubtensorResultInteractorInputProtocol,
        view: MockSubtensorResultViewProtocol = MockSubtensorResultViewProtocol(),
        request: SubtensorOperationResultRequest? = nil
    ) -> Setup {
        let wireframe = MockSubtensorResultWireframeProtocol()
        let delegate = MockSubtensorOperationResultDelegate()
        let chainAsset = SubtensorFlowChainWorld.chainAsset()

        let presenter = SubtensorOperationResultPresenter(
            request: request ?? makeRequest(),
            stakingOption: Multistaking.ChainAssetOption(chainAsset: chainAsset, type: .subtensor),
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: SubtensorOperationResultViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: CurrencyManagerStub())
            ),
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        presenter.delegate = delegate

        return Setup(presenter: presenter, view: view, wireframe: wireframe, delegate: delegate)
    }

    func stubStatusDetails(on view: MockSubtensorResultViewProtocol, closure: @escaping (String) -> Void) {
        stub(view) { stub in
            when(stub.didUpdateCountdown(remainedTime: any())).thenDoNothing()
            when(stub.didReceive(viewModel: any())).then { viewModel in
                if case let .page(page) = viewModel {
                    closure(page.status.details)
                }
            }
        }
    }
}
