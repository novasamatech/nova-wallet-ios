import UIKit
import SubstrateSdk
import Foundation_iOS
import UIKit_iOS

final class StakingMainViewController: UIViewController, AdaptiveDesignable, ViewHolder {
    typealias RootViewType = StakingMainViewLayout

    private enum Constants {
        static let verticalSpacing: CGFloat = 0.0
        static let bottomInset: CGFloat = 8.0
    }

    let presenter: StakingMainPresenterProtocol

    var scrollView: UIScrollView { rootView.containerView.scrollView }
    var stackView: UIStackView { rootView.containerView.stackView }

    private var networkInfoContainerView: UIView!
    private var networkInfoView: NetworkInfoView!
    private var rewardContainerView: UIView?
    private var rewardView: StakingRewardView?
    private lazy var alertsContainerView = UIView()
    private lazy var alertsView = AlertsView()

    private var actionsView: StakingActionsView?
    private var unbondingsView: StakingUnbondingsView?

    private var selectedEntityView: StackTableView?
    private var selectedEntityCell: StackAddressCell?

    private var stateContainerView: UIView?
    private var stateView: LocalizableView?

    private var balanceViewModel: LocalizableResource<String>?
    private var assetIconViewModel: ImageViewModelProtocol?
    private var staticsViewModel: StakingMainStaticViewModelProtocol?

    private var stateRawType: Int?

    var iconGenerator: IconGenerating?
    var uiFactory: UIFactoryProtocol?

    // MARK: - UIViewController

    init(presenter: StakingMainPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingMainViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAlertsView()
        setupNetworkInfoView()
        setupScrollView()
        setupLocalization()
        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        networkInfoView.didAppearSkeleton()

        if let skeletonState = stateView as? SkeletonLoadable {
            skeletonState.didAppearSkeleton()
        }

        rewardView?.didAppearSkeleton()

        selectedEntityCell?.didAppearSkeleton()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        networkInfoView.didDisappearSkeleton()

        if let skeletonState = stateView as? SkeletonLoadable {
            skeletonState.didDisappearSkeleton()
        }

        rewardView?.didDisappearSkeleton()

        selectedEntityCell?.didDisappearSkeleton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        networkInfoView.didUpdateSkeletonLayout()

        if let skeletonState = stateView as? SkeletonLoadable {
            skeletonState.didUpdateSkeletonLayout()
        }

        rewardView?.didUpdateSkeletonLayout()

        selectedEntityCell?.didUpdateSkeletonLayout()
    }

    // MARK: - Private functions

    @objc private func rewardPeriodAction() {
        presenter.selectPeriod()
    }

    @objc private func claimRewardsAction() {
        presenter.performClaimRewards()
    }

    private func setupScrollView() {
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
    }

    private func setupEntityView(for viewModel: StakingSelectedEntityViewModel) {
        let entityView: StackTableView

        if let selectedEntityView = selectedEntityView {
            entityView = selectedEntityView
        } else {
            let containerView = UIView()

            entityView = StackTableView()

            if let beforeView = networkInfoContainerView {
                stackView.insertArranged(view: containerView, before: beforeView)
            } else {
                stackView.addArrangedSubview(containerView)
            }

            stackView.setCustomSpacing(8, after: containerView)

            containerView.snp.makeConstraints { make in
                make.width.equalToSuperview()
            }

            containerView.addSubview(entityView)
            entityView.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            }

            selectedEntityView = entityView
        }

        entityView.clear()

        entityView.contentInsets = UIEdgeInsets(top: 4.0, left: 16.0, bottom: 8.0, right: 16.0)

        let tableHeader = StackTableHeaderCell()
        tableHeader.titleLabel.text = viewModel.title
        tableHeader.titleLabel.apply(style: .regularSubhedlineSecondary)
        entityView.addArrangedSubview(tableHeader)

        let addressCell = StackAddressCell()
        entityView.addArrangedSubview(addressCell)

        selectedEntityCell = addressCell

        addressCell.bind(viewModel: viewModel.loadingAddress)
    }

    private func setupNetworkInfoView() {
        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 343.0, height: 296))
        let networkInfoView = NetworkInfoView(frame: defaultFrame)

        self.networkInfoView = networkInfoView

        networkInfoView.delegate = self
        networkInfoView.statics = staticsViewModel

        networkInfoContainerView = UIView()
        networkInfoContainerView.translatesAutoresizingMaskIntoConstraints = false

        networkInfoContainerView.addSubview(networkInfoView)

        applyConstraints(for: networkInfoContainerView, innerView: networkInfoView)

        stackView.addArrangedSubview(networkInfoContainerView)
    }

    private func setupAlertsView() {
        alertsContainerView.translatesAutoresizingMaskIntoConstraints = false
        alertsContainerView.addSubview(alertsView)

        applyConstraints(for: alertsContainerView, innerView: alertsView)

        stackView.insertArrangedSubview(alertsContainerView, at: 0)

        alertsView.delegate = self
    }

    private func setupStakingRewardViewIfNeeded() {
        guard rewardContainerView == nil else {
            return
        }

        let containerView = UIView()

        let rewardView = StakingRewardView()
        rewardView.locale = localizationManager?.selectedLocale ?? Locale.current
        rewardView.filterView.control.addTarget(
            self,
            action: #selector(rewardPeriodAction),
            for: .touchUpInside
        )
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
            newActionsView.statics = staticsViewModel
            stackView.insertArranged(view: newActionsView, before: networkInfoContainerView)
            newActionsView.snp.makeConstraints { make in
                make.width.equalToSuperview()
            }

            stackView.setCustomSpacing(8.0, after: newActionsView)

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
                stackView.insertArranged(view: newUnbondingsView, before: networkInfoContainerView)
            }

            newUnbondingsView.snp.makeConstraints { make in
                make.width.equalToSuperview()
            }

            stackView.setCustomSpacing(8.0, after: newUnbondingsView)

            unbondingsView = newUnbondingsView
        }

        unbondingsView?.bind(viewModel: unbondingViewModel)
    }

    private func clearStateView() {
        if let containerView = stateContainerView {
            stackView.removeArrangedSubview(containerView)
            containerView.removeFromSuperview()
        }

        stateContainerView = nil
        stateView = nil
        alertsContainerView.isHidden = true
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

    private func setupNominatorViewIfNeeded() -> NominatorStateView? {
        if let nominatorView = stateView as? NominatorStateView {
            return nominatorView
        }

        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 343, height: 160.0))
        let stateView = setupView { NominatorStateView(frame: defaultFrame) }
        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current
        stateView?.statics = staticsViewModel

        return stateView
    }

    private func setupValidatorViewIfNeeded() -> ValidatorStateView? {
        if let validator = stateView as? ValidatorStateView {
            return validator
        }

        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 343, height: 160.0))
        let stateView = setupView { ValidatorStateView(frame: defaultFrame) }
        stateView?.locale = localizationManager?.selectedLocale ?? Locale.current
        stateView?.statics = staticsViewModel

        return stateView
    }

    private func applyNominator(viewModel: LocalizableResource<NominationViewModel>) {
        let nominatorView = setupNominatorViewIfNeeded()
        nominatorView?.bind(viewModel: viewModel)
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

        rewardView?.claimButton?.addTarget(
            self,
            action: #selector(claimRewardsAction),
            for: .touchUpInside
        )
    }
}

extension StakingMainViewController: Localizable {
    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        networkInfoView.locale = locale
        stateView?.locale = locale
        alertsView.locale = locale
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

extension StakingMainViewController: StakingMainViewProtocol {
    func didReceiveSelectedEntity(_ entity: StakingSelectedEntityViewModel) {
        setupEntityView(for: entity)
    }

    func didRecieveNetworkStakingInfo(viewModel: NetworkStakingInfoViewModel) {
        networkInfoView.bind(viewModel: viewModel)
    }

    func didReceive(viewModel: StakingMainViewModel) {
        title = R.string(preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingOnNetwork(viewModel.chainName)
    }

    func didReceiveStakingState(viewModel: StakingViewState) {
        let hasSameTypes = viewModel.rawType == stateRawType
        stateRawType = viewModel.rawType

        switch viewModel {
        case .undefined:
            clearStateView()
            clearStakingRewardViewIfNeeded()
            updateActionsView(for: nil)
            updateUnbondingsView(for: nil)
        case let .nominator(viewModel, alerts, optReward, unbondings, actions):
            applyNominator(viewModel: viewModel)
            applyAlerts(alerts)

            if let reward = optReward {
                applyStakingReward(viewModel: reward)
            } else {
                clearStakingRewardViewIfNeeded()
            }

            if !hasSameTypes {
                expandNetworkInfoView(false)
            }

            updateActionsView(for: actions)
            updateUnbondingsView(for: unbondings)
        case let .validator(viewModel, alerts, optReward, unbondings, actions):
            applyValidator(viewModel: viewModel)
            applyAlerts(alerts)

            if let reward = optReward {
                applyStakingReward(viewModel: reward)
            } else {
                clearStakingRewardViewIfNeeded()
            }

            if !hasSameTypes {
                expandNetworkInfoView(false)
            }

            updateActionsView(for: actions)
            updateUnbondingsView(for: unbondings)
        }
    }

    func expandNetworkInfoView(_ isExpanded: Bool) {
        networkInfoView.setExpanded(isExpanded, animated: false)
    }

    func didReceiveStatics(viewModel: StakingMainStaticViewModelProtocol) {
        staticsViewModel = viewModel

        networkInfoView.statics = viewModel
        actionsView?.statics = viewModel

        if let stateView = stateView as? StakingStateView {
            stateView.statics = viewModel
        }
    }

    func didEditRewardFilters() {
        rewardView?.filterView.control.deactivate(animated: true)
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

extension StakingMainViewController: AlertsViewDelegate {
    func didSelectStakingAlert(_ alert: StakingAlert) {
        presenter.performAlertAction(alert)
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
