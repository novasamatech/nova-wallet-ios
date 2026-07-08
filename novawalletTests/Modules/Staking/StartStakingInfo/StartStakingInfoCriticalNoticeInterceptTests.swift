import XCTest
import BigInt
import Foundation_iOS
@testable import novawallet

// MARK: - Tests

final class StartStakingInfoCriticalNoticeInterceptTests: XCTestCase {
    // MARK: Helpers

    /// Held strongly so presenter.view (which is weak) stays alive for the test duration.
    private var retainedView: MockStartStakingInfoView?

    override func tearDown() {
        retainedView = nil
        super.tearDown()
    }

    /// Builds a presenter wired with the given noticesProvider and wireframe.
    /// The presenter's view is assigned and accountExistense is pre-loaded to
    /// .assetBalance so `proceedToStakingSetup()` can reach `wireframe.showSetupAmount`.
    private func makePresenter(
        noticesProvider: MockStakingNoticesProvider,
        wireframe: MockStartStakingInfoWireframe
    ) -> StartStakingInfoRelaychainPresenter {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 42,
            hasStaking: true
        )
        let asset = chain.assets.first!
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let interactor = MockStartStakingInfoRelaychainInteractor()

        let presenter = StartStakingInfoRelaychainPresenter(
            selectedStakingType: nil,
            chainAsset: chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            startStakingViewModelFactory: MockStartStakingViewModelFactory(),
            balanceDerivationFactory: MockStakingTypeBalanceFactory(),
            localizationManager: LocalizationManager.shared,
            applicationConfig: ApplicationConfig.shared,
            noticesProvider: noticesProvider,
            logger: Logger.shared
        )

        let view = MockStartStakingInfoView()
        // Keep view alive: presenter.view is weak, so without a strong reference it would
        // be freed before startStaking() is called and proceedToStakingSetup would bail out.
        retainedView = view
        presenter.view = view

        // Push accountExistense = .assetBalance so proceedToStakingSetup reaches showSetupAmount.
        let chainAssetId = ChainAssetId(chainId: chainAsset.chain.chainId, assetId: chainAsset.asset.assetId)
        let balance = AssetBalance.createZero(for: chainAssetId, accountId: Data(repeating: 0, count: 32))
        presenter.didReceive(assetBalance: balance)

        return presenter
    }

    // MARK: - Test: no notice → showSetupAmount is called directly

    func testNoNoticeCallsShowSetupAmount() {
        // given
        let noticesProvider = MockStakingNoticesProvider()
        // no entry → notice(for:) returns nil
        let wireframe = MockStartStakingInfoWireframe()
        let presenter = makePresenter(noticesProvider: noticesProvider, wireframe: wireframe)

        // when
        presenter.startStaking()

        // then
        XCTAssertEqual(wireframe.showSetupAmountCalls, 1, "showSetupAmount should be called once")
        XCTAssertEqual(wireframe.presentCriticalNoticeSheetCalls.count, 0, "modal should NOT be presented")
    }

    // MARK: - Test: info-severity notice → showSetupAmount is called directly

    func testInfoNoticeCallsShowSetupAmount() {
        // given
        let noticesProvider = MockStakingNoticesProvider()
        let wireframe = MockStartStakingInfoWireframe()
        let presenter = makePresenter(noticesProvider: noticesProvider, wireframe: wireframe)

        // inject an info-severity notice for this chain
        let chainId = presenter.chainAsset.chain.chainId
        noticesProvider.notices[chainId] = StakingNotice(
            chainId: chainId,
            severity: .info,
            shortText: "Info title",
            longText: "Info body",
            endDate: nil
        )

        // when
        presenter.startStaking()

        // then
        XCTAssertEqual(wireframe.showSetupAmountCalls, 1, "showSetupAmount should be called once for info notice")
        XCTAssertEqual(wireframe.presentCriticalNoticeSheetCalls.count, 0, "modal should NOT be presented for info notice")
    }

    // MARK: - Test: critical notice → modal sheet is presented

    func testCriticalNoticePresentsCriticalSheet() {
        // given
        let noticesProvider = MockStakingNoticesProvider()
        let wireframe = MockStartStakingInfoWireframe()
        let presenter = makePresenter(noticesProvider: noticesProvider, wireframe: wireframe)

        let chainId = presenter.chainAsset.chain.chainId
        let expectedShortText = "Network compromised"
        let expectedLongText = "This network has a critical security issue."
        noticesProvider.notices[chainId] = StakingNotice(
            chainId: chainId,
            severity: .critical,
            shortText: expectedShortText,
            longText: expectedLongText,
            endDate: nil
        )

        // when
        presenter.startStaking()

        // then
        XCTAssertEqual(wireframe.presentCriticalNoticeSheetCalls.count, 1, "modal should be presented for critical notice")
        XCTAssertEqual(wireframe.showSetupAmountCalls, 0, "showSetupAmount should NOT be called directly for critical notice")

        let call = wireframe.presentCriticalNoticeSheetCalls.first
        XCTAssertEqual(call?.title, expectedShortText)
        XCTAssertEqual(call?.body, expectedLongText)
    }

    // MARK: - Bonus: critical notice onContinue → calls showSetupAmount

    func testCriticalNoticeOnContinueCallsShowSetupAmount() {
        // given
        let noticesProvider = MockStakingNoticesProvider()
        let wireframe = MockStartStakingInfoWireframe()
        let presenter = makePresenter(noticesProvider: noticesProvider, wireframe: wireframe)

        let chainId = presenter.chainAsset.chain.chainId
        noticesProvider.notices[chainId] = StakingNotice(
            chainId: chainId,
            severity: .critical,
            shortText: "Critical",
            longText: "Long body",
            endDate: nil
        )

        // when: present the modal
        presenter.startStaking()

        // sanity: modal was shown, setup amount not yet called
        XCTAssertEqual(wireframe.presentCriticalNoticeSheetCalls.count, 1)
        XCTAssertEqual(wireframe.showSetupAmountCalls, 0)

        // when: user taps Continue
        wireframe.presentCriticalNoticeSheetCalls.first?.onContinue()

        // then: setup amount flow is triggered
        XCTAssertEqual(wireframe.showSetupAmountCalls, 1, "onContinue should route to setup-amount screen")
    }
}

// MARK: - Mocks

private final class MockStartStakingInfoView: StartStakingInfoViewProtocol {
    var isSetup: Bool { false }
    var controller: UIViewController { UIViewController() }

    func didReceive(viewModel _: LoadableViewModelState<StartStakingViewModel>) {}
    func didReceive(balance _: String) {}
    func didReceiveNotice(_: StakingNoticeBlockView.Model?) {}
}

private final class MockStartStakingInfoWireframe: StartStakingInfoWireframeProtocol {
    // MARK: Recorded calls

    struct CriticalNoticeSheetCall {
        let title: String
        let body: String
        let onContinue: () -> Void
    }

    var presentCriticalNoticeSheetCalls: [CriticalNoticeSheetCall] = []
    var showSetupAmountCalls = 0

    // MARK: StartStakingInfoWireframeProtocol

    func presentCriticalNoticeSheet(
        from _: StartStakingInfoViewProtocol?,
        title: String,
        body: String,
        onCancel _: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        presentCriticalNoticeSheetCalls.append(.init(title: title, body: body, onContinue: onContinue))
    }

    func showSetupAmount(from _: ControllerBackedProtocol?) {
        showSetupAmountCalls += 1
    }

    func showWalletDetails(from _: ControllerBackedProtocol?, wallet _: MetaAccountModel) {}
    func complete(from _: ControllerBackedProtocol?) {}

    // MARK: AlertPresentable

    func present(message _: String?, title _: String?, closeAction _: String?, from _: ControllerBackedProtocol?) {}
    func present(viewModel _: AlertPresentableViewModel, style _: UIAlertController.Style, from _: ControllerBackedProtocol?) {}

    // MARK: ErrorPresentable

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { false }

    // MARK: CommonRetryable

    func presentRequestStatus(on _: ControllerBackedProtocol?, with _: RequestStatusAlertModel) {}
    func presentTryAgainOperation(on _: ControllerBackedProtocol?, title _: String, message _: String, actionTitle _: String, retryAction _: @escaping () -> Void) {}

    // MARK: NoAccountSupportPresentable

    func presentNoAccountSupport(from _: ControllerBackedProtocol, walletType _: MetaAccountModelType, chainName _: String, locale _: Locale) {}
    func presentAddAccount(from _: ControllerBackedProtocol, chainName _: String, message _: String, locale _: Locale, addClosure _: @escaping () -> Void) {}

    // MARK: StakingErrorPresentable (minimum stubs needed)

    func presentAmountTooLow(value _: String, from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentMissingController(from _: ControllerBackedProtocol, address _: AccountAddress, locale _: Locale?) {}
    func presentMissingStash(from _: ControllerBackedProtocol, address _: AccountAddress, locale _: Locale?) {}
    func presentUnbondingTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentRebondingTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentRewardIsLessThanFee(from _: ControllerBackedProtocol, action _: @escaping () -> Void, locale _: Locale?) {}
    func presentControllerBalanceIsZero(from _: ControllerBackedProtocol, action _: @escaping () -> Void, locale _: Locale?) {}
    func presentUnbondingLimitReached(from _: ControllerBackedProtocol?, locale _: Locale?) {}
    func presentNoRedeemables(from _: ControllerBackedProtocol?, locale _: Locale?) {}
    func presentControllerIsAlreadyUsed(from _: ControllerBackedProtocol?, locale _: Locale?) {}
    func presentDeselectValidatorsWarning(from _: ControllerBackedProtocol, action _: @escaping () -> Void, locale _: Locale?) {}
    func presentMaxNumberOfNominatorsReached(from _: ControllerBackedProtocol?, stakingType _: String, locale _: Locale?) {}
    func presentMinRewardableStakeViolated(from _: ControllerBackedProtocol, action _: @escaping () -> Void, minStake _: String, locale _: Locale?) {}
    func presentLockedTokensInPoolStaking(from _: ControllerBackedProtocol?, lockReason _: String, availableToStake _: String, directRewardableToStake _: String, locale _: Locale?) {}
    func presentAlreadyHaveStaking(from _: ControllerBackedProtocol?, networkName _: String, onClose _: @escaping () -> Void, locale _: Locale?) {}
    func presentDirectAndPoolStakingConflict(from _: ControllerBackedProtocol?, locale _: Locale?) {}

    // MARK: BaseErrorPresentable stubs

    func presentAmountTooHigh(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentFeeNotReceived(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentFeeTooHigh(from _: ControllerBackedProtocol, balance _: String, fee _: String, locale _: Locale?) {}
    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) {}
    func presentInvalidAddress(from _: ControllerBackedProtocol, chainName _: String, locale _: Locale?) {}
    func presentUpToForFee(from _: ControllerBackedProtocol, available _: String, fee _: String, maxClosure _: (() -> Void)?, locale _: Locale?) {}
    func presentExistentialDepositWarning(from _: ControllerBackedProtocol, action _: @escaping () -> Void, locale _: Locale?) {}
    func presentIsSystemAccount(from _: ControllerBackedProtocol?, onContinue _: @escaping () -> Void, locale _: Locale?) {}
    func presentMinBalanceViolated(from _: ControllerBackedProtocol, minBalanceForOperation _: String, currentBalance _: String, needToAddBalance _: String, locale _: Locale?) {}

    // MARK: StakingBaseErrorPresentable stubs

    func presentCrossedMinStake(from _: ControllerBackedProtocol?, minStake _: String, remaining _: String, action _: @escaping () -> Void, locale _: Locale) {}
}

private final class MockStakingNoticesProvider: StakingNoticesProviding {
    var notices: [ChainModel.Id: StakingNotice] = [:]
    var allNotices: [ChainModel.Id: StakingNotice] { notices }
    func notice(for chainId: ChainModel.Id) -> StakingNotice? { notices[chainId] }
    func refresh() {}
    func subscribe(_: AnyObject, callback _: @escaping () -> Void) {}
    func unsubscribe(_: AnyObject) {}
}

private final class MockStartStakingInfoRelaychainInteractor: StartStakingInfoRelaychainInteractorInputProtocol {
    func setup() {}
    func remakeSubscriptions() {}
    func retryDirectStakingMinStake() {}
    func retryEraCompletionTime() {}
    func retryNominationPoolsMinStake() {}
    func remakeCalculator() {}
}

private final class MockStartStakingViewModelFactory: StartStakingViewModelFactoryProtocol {
    private static let dummyURL = URL(string: "https://example.com")!
    private static let dummyParagraph = ParagraphView.Model(image: nil, text: AccentTextModel(text: "", accents: []))
    private static let dummyUrlModel = StartStakingUrlModel(text: "", url: dummyURL, urlName: "")

    func earnupModel(earnings _: Decimal?, chainAsset _: ChainAsset, locale _: Locale) -> AccentTextModel {
        AccentTextModel(text: "", accents: [])
    }

    func stakeModel(minStake _: BigUInt?, rewardStartDelay _: TimeInterval, chainAsset _: ChainAsset, locale _: Locale) -> ParagraphView.Model {
        Self.dummyParagraph
    }

    func unstakeModel(unstakePeriod _: TimeInterval, locale _: Locale) -> ParagraphView.Model {
        Self.dummyParagraph
    }

    func rewardModel(amount _: BigUInt?, chainAsset _: ChainAsset, rewardTimeInterval _: TimeInterval, destination _: DefaultStakingRewardDestination, locale _: Locale) -> ParagraphView.Model {
        Self.dummyParagraph
    }

    func govModel(amount _: BigUInt?, chainAsset _: ChainAsset, locale _: Locale) -> ParagraphView.Model {
        Self.dummyParagraph
    }

    func recommendationModel(locale _: Locale) -> ParagraphView.Model {
        Self.dummyParagraph
    }

    func testNetworkModel(chain _: ChainModel, locale _: Locale) -> ParagraphView.Model {
        Self.dummyParagraph
    }

    func wikiModel(url _: URL, chainAsset _: ChainAsset, locale _: Locale) -> StartStakingUrlModel {
        Self.dummyUrlModel
    }

    func termsModel(url _: URL, locale _: Locale) -> StartStakingUrlModel {
        Self.dummyUrlModel
    }

    func balance(amount _: BigUInt?, priceData _: PriceData?, chainAsset _: ChainAsset, locale _: Locale) -> String {
        ""
    }

    func noAccount(chain _: ChainModel, locale _: Locale) -> String {
        ""
    }
}

private final class MockStakingTypeBalanceFactory: StakingTypeBalanceFactoryProtocol {
    func getAvailableBalance(from _: AssetBalance?, stakingMethod _: StakingSelectionMethod) -> BigUInt? {
        nil
    }

    func getStakeableBalance(from _: AssetBalance?, existentialDeposit _: BigUInt?, stakingMethod _: StakingSelectionMethod) -> BigUInt? {
        nil
    }
}
