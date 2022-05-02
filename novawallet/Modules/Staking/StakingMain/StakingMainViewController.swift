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

    private var backgroundView = MultigradientView.background

    let assetSelectionContainerView = UIView()
    let assetSelectionView: DetailsTriangularedView = {
        let view = UIFactory.default.createChainAssetSelectionView()
        view.borderWidth = 0.0
        view.actionImage = R.image.iconMore()?.withRenderingMode(.alwaysTemplate)
        view.actionView.tintColor = R.color.colorWhite48()
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

    private var actionsView: StakingActionsView?
    private var unbondingsView: StakingUnbondingsView?

    private var stateContainerView: UIView?
    private var stateView: LocalizableView?

    private var balanceViewModel: LocalizableResource<String>?
    private var assetIconViewModel: ImageViewModelProtocol?

    var iconGenerator: IconGenerating?
    var uiFactory: UIFactoryProtocol?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        setupBackgroundView()
        setupAssetSelectionView()
        setupNetworkInfoView()
        setupAlertsView()
        setupAnalyticsView()
        setupScrollView()
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

    private func setupScrollView() {
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
    }

    private func setupBackgroundView() {
        view.insertSubview(backgroundView, at: 0)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupAssetSelectionView() {
        assetSelectionContainerView.translatesAutoresizingMaskIntoConstraints = false

        let backgroundView = TriangularedBlurView()
        assetSelectionContainerView.addSubview(backgroundView)
        assetSelectionContainerView.addSubview(assetSelectionView)

        applyConstraints(for: assetSelectionContainerView, innerView: assetSelectionView)

        stackView.insertArranged(view: assetSelectionContainerView, after: headerView)

        assetSelectionView.snp.makeConstraints { make in
            make.height.equalTo(52.0)
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

        stackView.insertArranged(view: alertsContainerView, after: networkInfoContainerView)

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
        rewardView.locale = localizationManager?.selectedLocale ?? Locale.current
        containerView.addSubview(rewardView)

        applyConstraints(for: containerView, innerView: rewardView)

        stackView.insertArranged(view: containerView, after: alertsContainerView)

        rewardContainerView = containerView
        self.rewardView = rewardView
    }

    private func clearStakingRewardViewIfNeeded() {
        rewardContainerView?.removeFromSuperview()
        rewardContainerView = nil
        rewardView = nil
    }

    private func updateActionsView(for stakingActions: [StakingManageOption]?) {
        guard let stakingActions = stakingActions, !stakingActions.isEmpty else {
            actionsView?.removeFromSuperview()
            actionsView = nil

            return
        }

        if actionsView == nil {
            let newActionsView = StakingActionsView()
            newActionsView.locale = selectedLocale
            newActionsView.delegate = self
            stackView.addArrangedSubview(newActionsView)
            newActionsView.snp.makeConstraints { make in
                make.width.equalToSuperview()
            }

            actionsView = newActionsView
        }

        actionsView?.bind(actions: stakingActions)
    }

    private func updateUnbondingsView(for unbondingViewModel: StakingUnbondingViewModel?) {
        guard let unbondingViewModel = unbondingViewModel, !unbondingViewModel.items.isEmpty else {
            unbondingsView?.removeFromSuperview()
            unbondingsView = nil

            return
        }

        if unbondingsView == nil {
            let newUnbondingsView = StakingUnbondingsView()
            newUnbondingsView.locale = selectedLocale
            newUnbondingsView.delegate = self

            if let stateView = stateContainerView {
                stackView.insertArranged(view: newUnbondingsView, after: stateView)
            } else {
                stackView.addArrangedSubview(newUnbondingsView)
            }

            newUnbondingsView.snp.makeConstraints { make in
                make.width.equalToSuperview()
            }

            stackView.setCustomSpacing(8.0, after: newUnbondingsView)

            unbondingsView = newUnbondingsView
        }

        unbondingsView?.bind(viewModel: unbondingViewModel)
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
            stackView.insertArranged(view: containerView, after: alertsContainerView)
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

        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 343, height: 160.0))
        let stateView = setupView { NominatorStateView(frame: defaultFrame) }
        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current

        return stateView
    }

    private func setupValidatorViewIfNeeded() -> ValidatorStateView? {
        if let validator = stateView as? ValidatorStateView {
            return validator
        }

        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 343, height: 160.0))
        let stateView = setupView { ValidatorStateView(frame: defaultFrame) }
        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current

        return stateView
    }

    private func applyNominator(viewModel: LocalizableResource<NominationViewModel>) {
        let nominatorView = setupNominatorViewIfNeeded()
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
        actionsView?.locale = locale
        unbondingsView?.locale = locale
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
            updateActionsView(for: nil)
            updateUnbondingsView(for: nil)
        case let .noStash(viewModel, alerts):
            applyNoStash(viewModel: viewModel)
            applyAlerts(alerts)
            expandNetworkInfoView(true)
            clearStakingRewardViewIfNeeded()
            updateActionsView(for: nil)
            updateUnbondingsView(for: nil)
        case let .nominator(viewModel, alerts, reward, analyticsViewModel, unbondings, actions):
            applyNominator(viewModel: viewModel)
            applyAlerts(alerts)
            applyStakingReward(viewModel: reward)
            applyAnalyticsRewards(viewModel: analyticsViewModel)
            expandNetworkInfoView(false)
            updateActionsView(for: actions)
            updateUnbondingsView(for: unbondings)
        case let .validator(viewModel, alerts, reward, analyticsViewModel, unbondings, actions):
            applyValidator(viewModel: viewModel)
            applyAlerts(alerts)
            applyStakingReward(viewModel: reward)
            applyAnalyticsRewards(viewModel: analyticsViewModel)
            expandNetworkInfoView(false)
            updateActionsView(for: actions)
            updateUnbondingsView(for: unbondings)
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

extension StakingMainViewController: HiddableBarWhenPushed {}

extension StakingMainViewController: AlertsViewDelegate {
    func didSelectStakingAlert(_ alert: StakingAlert) {
        switch alert {
        case .nominatorChangeValidators, .nominatorAllOversubscribed:
            presenter.performChangeValidatorsAction()
        case .bondedSetValidators:
            presenter.performSetupValidatorsForBondedAction()
        case .nominatorLowStake:
            presenter.performStakeMoreAction()
        case .redeemUnbonded:
            presenter.performRedeemAction()
        case .waitingNextEra:
            break
        }
    }
}

extension StakingMainViewController: StakingActionsViewDelegate {
    func actionsViewDidSelectAction(_ action: StakingManageOption) {
        presenter.performManageAction(action)
    }
}

extension StakingMainViewController: StakingUnbondingsViewDelegate {
    func stakingUnbondingViewDidCancel(_: StakingUnbondingsView) {
        presenter.performRebondAction()
    }

    func stakingUnbondingViewDidRedeem(_: StakingUnbondingsView) {
        presenter.performRedeemAction()
    }
}
