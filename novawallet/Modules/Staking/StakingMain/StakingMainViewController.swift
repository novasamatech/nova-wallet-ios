import UIKit
import SubstrateSdk
import SoraFoundation
import SoraUI
import CommonWallet

final class StakingMainViewController: UIViewController, AdaptiveDesignable {
    private enum Constants {
        static let verticalSpacing: CGFloat = 0.0
        static let bottomInset: CGFloat = 8.0
    }

    var presenter: StakingMainPresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var headerView: UIView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconButton: RoundedButton!
    @IBOutlet private var iconButtonWidth: NSLayoutConstraint!

    let assetSelectionContainerView = UIView()
    let assetSelectionView: DetailsTriangularedView = {
        let view = UIFactory.default.createChainAssetSelectionView()
        view.borderWidth = 0.0
        return view
    }()

    private var networkInfoContainerView: UIView!
    private var networkInfoView: NetworkInfoView!
    private var rewardContainerView: UIView?
    private var rewardView: StakingRewardView?
    private lazy var alertsContainerView = UIView()
    private lazy var alertsView = AlertsView()
    private lazy var analyticsContainerView = UIView()
    private lazy var analyticsView = RewardAnalyticsWidgetView()

    private var stateContainerView: UIView?
    private var stateView: LocalizableView?

    private var balanceViewModel: LocalizableResource<String>?
    private var assetIconViewModel: ImageViewModelProtocol?

    var iconGenerator: IconGenerating?
    var uiFactory: UIFactoryProtocol?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAssetSelectionView()
        setupNetworkInfoView()
        setupAlertsView()
        setupAnalyticsView()
        setupLocalization()
        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        networkInfoView.didAppearSkeleton()
        analyticsView.didAppearSkeleton()

        if let skeletonState = stateView as? SkeletonLoadable {
            skeletonState.didAppearSkeleton()
        }

        rewardView?.didAppearSkeleton()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        networkInfoView.didDisappearSkeleton()
        analyticsView.didDisappearSkeleton()

        if let skeletonState = stateView as? SkeletonLoadable {
            skeletonState.didDisappearSkeleton()
        }

        rewardView?.didDisappearSkeleton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        networkInfoView.didUpdateSkeletonLayout()
        analyticsView.didUpdateSkeletonLayout()

        if let skeletonState = stateView as? SkeletonLoadable {
            skeletonState.didUpdateSkeletonLayout()
        }

        rewardView?.didUpdateSkeletonLayout()
    }

    @IBAction func actionIcon() {
        presenter.performAccountAction()
    }

    // MARK: - Private functions

    private func setupAssetSelectionView() {
        assetSelectionContainerView.translatesAutoresizingMaskIntoConstraints = false

        let backgroundView = TriangularedBlurView()
        assetSelectionContainerView.addSubview(backgroundView)
        assetSelectionContainerView.addSubview(assetSelectionView)

        applyConstraints(for: assetSelectionContainerView, innerView: assetSelectionView)

        stackView.insertArranged(view: assetSelectionContainerView, after: headerView)

        assetSelectionView.snp.makeConstraints { make in
            make.height.equalTo(48.0)
        }

        backgroundView.snp.makeConstraints { make in
            make.edges.equalTo(assetSelectionView)
        }

        assetSelectionView.addTarget(
            self,
            action: #selector(actionAssetSelection),
            for: .touchUpInside
        )
    }

    private func setupNetworkInfoView() {
        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 343.0, height: 296))
        let networkInfoView = NetworkInfoView(frame: defaultFrame)

        self.networkInfoView = networkInfoView

        networkInfoView.delegate = self

        networkInfoContainerView = UIView()
        networkInfoContainerView.translatesAutoresizingMaskIntoConstraints = false

        networkInfoContainerView.addSubview(networkInfoView)

        applyConstraints(for: networkInfoContainerView, innerView: networkInfoView)

        stackView.insertArranged(view: networkInfoContainerView, after: assetSelectionContainerView)
    }

    private func setupAlertsView() {
        alertsContainerView.translatesAutoresizingMaskIntoConstraints = false
        alertsContainerView.addSubview(alertsView)

        applyConstraints(for: alertsContainerView, innerView: alertsView)

        if let stateContainerView = stateContainerView {
            stackView.insertArranged(view: alertsContainerView, after: stateContainerView)
        } else if let rewardContainerView = rewardContainerView {
            stackView.insertArranged(view: alertsContainerView, after: rewardContainerView)
        } else {
            stackView.insertArranged(view: alertsContainerView, after: networkInfoContainerView)
        }

        alertsView.delegate = self
    }

    private func setupAnalyticsView() {
        analyticsContainerView.translatesAutoresizingMaskIntoConstraints = false
        analyticsContainerView.addSubview(analyticsView)

        applyConstraints(for: analyticsContainerView, innerView: analyticsView)

        stackView.addArrangedSubview(analyticsContainerView)
        analyticsView.snp.makeConstraints { $0.height.equalTo(228) }
        analyticsView.backgroundButton.addTarget(self, action: #selector(handleAnalyticsWidgetTap), for: .touchUpInside)
    }

    private func setupStakingRewardViewIfNeeded() {
        guard rewardContainerView == nil else {
            return
        }

        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 343, height: 116.0))
        let containerView = UIView(frame: defaultFrame)
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let rewardView = StakingRewardView(frame: defaultFrame)
        containerView.addSubview(rewardView)

        applyConstraints(for: containerView, innerView: rewardView)

        stackView.insertArranged(view: containerView, after: networkInfoContainerView)

        rewardContainerView = containerView
        self.rewardView = rewardView
    }

    private func clearStakingRewardViewIfNeeded() {
        rewardContainerView?.removeFromSuperview()
        rewardContainerView = nil
        rewardView = nil
    }

    @objc
    private func handleAnalyticsWidgetTap() {
        presenter.performAnalyticsAction()
    }

    private func clearStateView() {
        if let containerView = stateContainerView {
            stackView.removeArrangedSubview(containerView)
            containerView.removeFromSuperview()
        }

        stateContainerView = nil
        stateView = nil
        alertsContainerView.isHidden = true
        analyticsContainerView.isHidden = true
    }

    private func applyConstraints(for containerView: UIView, innerView: UIView) {
        innerView.translatesAutoresizingMaskIntoConstraints = false
        innerView.leadingAnchor.constraint(
            equalTo: containerView.leadingAnchor,
            constant: UIConstants.horizontalInset
        ).isActive = true
        innerView.trailingAnchor.constraint(
            equalTo: containerView.trailingAnchor,
            constant: -UIConstants.horizontalInset
        ).isActive = true
        innerView.topAnchor.constraint(
            equalTo: containerView.topAnchor,
            constant: Constants.verticalSpacing
        ).isActive = true

        containerView.bottomAnchor.constraint(
            equalTo: innerView.bottomAnchor,
            constant: Constants.bottomInset
        ).isActive = true
    }

    private func setupView<T: LocalizableView>(for viewFactory: () -> T?) -> T? {
        clearStateView()

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        guard let stateView = viewFactory() else {
            return nil
        }

        containerView.addSubview(stateView)

        applyConstraints(for: containerView, innerView: stateView)

        if let rewardContainerView = rewardContainerView {
            stackView.insertArranged(view: containerView, after: rewardContainerView)
        } else {
            stackView.insertArranged(view: containerView, after: networkInfoContainerView)
        }

        stateContainerView = containerView
        self.stateView = stateView

        return stateView
    }

    private func setupRewardEstimationViewIfNeeded() -> RewardEstimationView? {
        if let rewardView = stateView as? RewardEstimationView {
            return rewardView
        }

        let size = CGSize(width: 343, height: 202.0)
        let stateView = setupView { RewardEstimationView(frame: CGRect(origin: .zero, size: size)) }

        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current
        stateView?.delegate = self

        return stateView
    }

    private func setupNominatorViewIfNeeded() -> NominatorStateView? {
        if let nominatorView = stateView as? NominatorStateView {
            return nominatorView
        }

        let stateView = setupView { NominatorStateView() }
        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current

        return stateView
    }

    private func setupValidatorViewIfNeeded() -> ValidatorStateView? {
        if let validator = stateView as? ValidatorStateView {
            return validator
        }

        let stateView = setupView { ValidatorStateView() }
        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current

        return stateView
    }

    private func applyNominator(viewModel: LocalizableResource<NominationViewModel>) {
        let nominatorView = setupNominatorViewIfNeeded()
        nominatorView?.delegate = self
        nominatorView?.bind(viewModel: viewModel)
    }

    private func applyBonded(viewModel: StakingEstimationViewModel) {
        let rewardView = setupRewardEstimationViewIfNeeded()
        rewardView?.bind(viewModel: viewModel)
    }

    private func applyNoStash(viewModel: StakingEstimationViewModel) {
        let rewardView = setupRewardEstimationViewIfNeeded()
        rewardView?.bind(viewModel: viewModel)
        scrollView.layoutIfNeeded()
    }

    private func applyValidator(viewModel: LocalizableResource<ValidationViewModel>) {
        let validatorView = setupValidatorViewIfNeeded()
        validatorView?.delegate = self
        validatorView?.bind(viewModel: viewModel)
    }

    private func applyAlerts(_ alerts: [StakingAlert]) {
        alertsContainerView.isHidden = alerts.isEmpty
        alertsView.bind(alerts: alerts)
        alertsContainerView.setNeedsLayout()
    }

    private func applyStakingReward(viewModel: LocalizableResource<StakingRewardViewModel>) {
        setupStakingRewardViewIfNeeded()
        rewardView?.bind(viewModel: viewModel)
    }

    private func applyAnalyticsRewards(viewModel _: LocalizableResource<RewardAnalyticsWidgetViewModel>?) {
        // TODO: Temporary disable Analytics feature
        // analyticsContainerView.isHidden = false
        // analyticsView.bind(viewModel: viewModel)
    }

    @objc func actionAssetSelection() {
        presenter.performAssetSelection()
    }
}

extension StakingMainViewController: Localizable {
    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        let languages = locale.rLanguages

        titleLabel.text = R.string.localizable
            .tabbarStakingTitle(preferredLanguages: languages)

        networkInfoView.locale = locale
        stateView?.locale = locale
        alertsView.locale = locale
        analyticsView.locale = locale
        rewardView?.locale = locale
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

extension StakingMainViewController: RewardEstimationViewDelegate {
    func rewardEstimationDidStartAction(_: RewardEstimationView) {
        presenter.performMainAction()
    }

    func rewardEstimationDidRequestInfo(_: RewardEstimationView) {
        presenter.performRewardInfoAction()
    }
}

extension StakingMainViewController: StakingMainViewProtocol {
    func didRecieveNetworkStakingInfo(
        viewModel: LocalizableResource<NetworkStakingInfoViewModel>?
    ) {
        networkInfoView.bind(viewModel: viewModel)
    }

    func didReceive(viewModel: StakingMainViewModel) {
        assetIconViewModel?.cancel(on: assetSelectionView.iconView)

        assetIconViewModel = viewModel.assetIcon
        balanceViewModel = viewModel.balanceViewModel

        let sideSize = iconButtonWidth.constant - iconButton.contentInsets.left
            - iconButton.contentInsets.right
        let size = CGSize(width: sideSize, height: sideSize)
        let icon = try? iconGenerator?.generateFromAddress(viewModel.address)
            .imageWithFillColor(R.color.colorWhite()!, size: size, contentScale: UIScreen.main.scale)
        iconButton.imageWithTitleView?.iconImage = icon
        iconButton.invalidateLayout()

        assetSelectionView.title = viewModel.assetName
        assetSelectionView.subtitle = viewModel.balanceViewModel?.value(for: selectedLocale)

        assetSelectionView.iconImage = nil

        let iconSize = 2 * assetSelectionView.iconRadius
        assetIconViewModel?.loadImage(
            on: assetSelectionView.iconView,
            targetSize: CGSize(width: iconSize, height: iconSize),
            animated: true
        )
    }

    func didReceiveStakingState(viewModel: StakingViewState) {
        switch viewModel {
        case .undefined:
            clearStateView()
            clearStakingRewardViewIfNeeded()
        case let .noStash(viewModel, alerts):
            applyNoStash(viewModel: viewModel)
            applyAlerts(alerts)
            expandNetworkInfoView(true)
            clearStakingRewardViewIfNeeded()
        case let .nominator(viewModel, alerts, reward, analyticsViewModel):
            applyNominator(viewModel: viewModel)
            applyAlerts(alerts)
            applyStakingReward(viewModel: reward)
            applyAnalyticsRewards(viewModel: analyticsViewModel)
            expandNetworkInfoView(false)
        case let .validator(viewModel, alerts, reward, analyticsViewModel):
            applyValidator(viewModel: viewModel)
            applyAlerts(alerts)
            applyStakingReward(viewModel: reward)
            applyAnalyticsRewards(viewModel: analyticsViewModel)
            expandNetworkInfoView(false)
        }
    }

    func expandNetworkInfoView(_ isExpanded: Bool) {
        networkInfoView.setExpanded(isExpanded, animated: false)
    }
}

extension StakingMainViewController: NetworkInfoViewDelegate {
    func animateAlongsideWithInfo(view _: NetworkInfoView) {
        scrollView.layoutIfNeeded()
    }

    func didChangeExpansion(isExpanded: Bool, view _: NetworkInfoView) {
        presenter.networkInfoViewDidChangeExpansion(isExpanded: isExpanded)
    }
}

// MARK: - StakingStateViewDelegate

extension StakingMainViewController: StakingStateViewDelegate {
    func stakingStateViewDidReceiveMoreAction(_: StakingStateView) {
        presenter.performManageStakingAction()
    }

    func stakingStateViewDidReceiveStatusAction(_ view: StakingStateView) {
        if view is NominatorStateView {
            presenter.performNominationStatusAction()
        } else if view is ValidatorStateView {
            presenter.performValidationStatusAction()
        }
    }
}

extension StakingMainViewController: HiddableBarWhenPushed {}

extension StakingMainViewController: AlertsViewDelegate {
    func didSelectStakingAlert(_ alert: StakingAlert) {
        switch alert {
        case .nominatorChangeValidators, .nominatorAllOversubscribed:
            presenter.performChangeValidatorsAction()
        case .bondedSetValidators:
            presenter.performSetupValidatorsForBondedAction()
        case .nominatorLowStake:
            presenter.performBondMoreAction()
        case .redeemUnbonded:
            presenter.performRedeemAction()
        case .waitingNextEra:
            break
        }
    }
}
