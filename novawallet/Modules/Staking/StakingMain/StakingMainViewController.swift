import UIKit
import SubstrateSdk
import Foundation_iOS
import UIKit_iOS

final class StakingMainViewController: UIViewController, AdaptiveDesignable, ViewHolder {
    typealias RootViewType = StakingMainViewLayout

    let presenter: StakingMainPresenterProtocol

    private var staticsViewModel: StakingMainStaticViewModelProtocol?

    private var stateRawType: Int?

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

        setupHandlers()
        setupLocalization()
        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        appearSkeletonView()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        disappearSkeletonView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateSkeletonLayouts()
    }
}

// MARK: - Private

private extension StakingMainViewController {
    func setupHandlers() {
        rootView.alertsView.delegate = self
        rootView.unbondingsView?.delegate = self

        rootView.rewardView?.claimButton?.removeTarget(
            self,
            action: #selector(claimRewardsAction),
            for: .touchUpInside
        )
        rootView.rewardView?.claimButton?.addTarget(
            self,
            action: #selector(claimRewardsAction),
            for: .touchUpInside
        )

        rootView.rewardView?.filterView.control.removeTarget(
            self,
            action: #selector(rewardPeriodAction),
            for: .touchUpInside
        )
        rootView.rewardView?.filterView.control.addTarget(
            self,
            action: #selector(rewardPeriodAction),
            for: .touchUpInside
        )

        rootView.ahmAlertView.closeButton.removeTarget(
            self,
            action: #selector(didTapAHMAlertClose),
            for: .touchUpInside
        )
        rootView.ahmAlertView.closeButton.addTarget(
            self,
            action: #selector(didTapAHMAlertClose),
            for: .touchUpInside
        )

        rootView.ahmAlertView.learnMoreButton.removeTarget(
            self,
            action: #selector(didTapAHMAlertLearnMore),
            for: .touchUpInside
        )
        rootView.ahmAlertView.learnMoreButton.addTarget(
            self,
            action: #selector(didTapAHMAlertLearnMore),
            for: .touchUpInside
        )
    }

    func setupLocalization() {
        rootView.locale = selectedLocale
        rootView.networkInfoView.locale = selectedLocale
        rootView.stateView?.locale = selectedLocale
        rootView.alertsView.locale = selectedLocale
        rootView.rewardView?.locale = selectedLocale
        rootView.actionsView?.locale = selectedLocale
        rootView.unbondingsView?.locale = selectedLocale
    }

    func updateSkeletonLayouts() {
        rootView.networkInfoView.didUpdateSkeletonLayout()

        if let skeletonState = rootView.stateView as? SkeletonLoadable {
            skeletonState.didUpdateSkeletonLayout()
        }

        rootView.rewardView?.didUpdateSkeletonLayout()

        rootView.selectedEntityCell?.didUpdateSkeletonLayout()
    }

    func appearSkeletonView() {
        rootView.networkInfoView.didAppearSkeleton()

        if let skeletonState = rootView.stateView as? SkeletonLoadable {
            skeletonState.didAppearSkeleton()
        }

        rootView.rewardView?.didAppearSkeleton()

        rootView.selectedEntityCell?.didAppearSkeleton()
    }

    func disappearSkeletonView() {
        rootView.networkInfoView.didDisappearSkeleton()

        if let skeletonState = rootView.stateView as? SkeletonLoadable {
            skeletonState.didDisappearSkeleton()
        }

        rootView.rewardView?.didDisappearSkeleton()

        rootView.selectedEntityCell?.didDisappearSkeleton()
    }

    @objc func rewardPeriodAction() {
        presenter.selectPeriod()
    }

    @objc func claimRewardsAction() {
        presenter.performClaimRewards()
    }

    @objc func didTapAHMAlertClose() {
        presenter.handleAHMAlertClose()
    }

    @objc func didTapAHMAlertLearnMore() {
        presenter.handleAHMAlertLearnMore()
    }
}

// MARK: - Localizable

extension StakingMainViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}

// MARK: - StakingMainViewProtocol

extension StakingMainViewController: StakingMainViewProtocol {
    func didReceiveSelectedEntity(_ entity: StakingSelectedEntityViewModel) {
        rootView.setupEntityView(for: entity)
    }

    func didRecieveNetworkStakingInfo(viewModel: NetworkStakingInfoViewModel) {
        rootView.networkInfoView.bind(viewModel: viewModel)
    }

    func didReceive(viewModel: StakingMainViewModel) {
        title = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.stakingOnNetwork(viewModel.chainName)
    }

    func didReceiveStakingState(viewModel: StakingViewState) {
        let hasSameTypes = viewModel.rawType == stateRawType
        stateRawType = viewModel.rawType

        switch viewModel {
        case .undefined:
            rootView.clearStateView()
            rootView.clearStakingRewardViewIfNeeded()
            rootView.updateActionsView(
                for: nil,
                delegate: self
            )
            rootView.updateUnbondingsView(for: nil)
        case let .nominator(viewModel, alerts, optReward, unbondings, actions):
            rootView.applyNominator(viewModel: viewModel)
            rootView.applyAlerts(alerts)

            if let reward = optReward {
                rootView.applyStakingReward(viewModel: reward)
            } else {
                rootView.clearStakingRewardViewIfNeeded()
            }

            if !hasSameTypes {
                expandNetworkInfoView(false)
            }

            rootView.updateActionsView(
                for: actions,
                delegate: self
            )
            rootView.updateUnbondingsView(for: unbondings)
        case let .validator(viewModel, alerts, optReward, unbondings, actions):
            rootView.applyValidator(viewModel: viewModel)
            rootView.applyAlerts(alerts)

            if let reward = optReward {
                rootView.applyStakingReward(viewModel: reward)
            } else {
                rootView.clearStakingRewardViewIfNeeded()
            }

            if !hasSameTypes {
                expandNetworkInfoView(false)
            }

            rootView.updateActionsView(
                for: actions,
                delegate: self
            )
            rootView.updateUnbondingsView(for: unbondings)
        }

        setupHandlers()
    }

    func expandNetworkInfoView(_ isExpanded: Bool) {
        rootView.networkInfoView.setExpanded(isExpanded, animated: false)
    }

    func didReceiveStatics(viewModel: StakingMainStaticViewModelProtocol) {
        staticsViewModel = viewModel

        rootView.networkInfoView.statics = viewModel
        rootView.actionsView?.statics = viewModel

        if let stateView = rootView.stateView as? StakingStateView {
            stateView.statics = viewModel
        }
    }

    func didEditRewardFilters() {
        rootView.rewardView?.filterView.control.deactivate(animated: true)
    }

    func didReceiveAHMAlert(viewModel: AHMAlertView.Model?) {
        rootView.setAHMAlert(with: viewModel)
    }
}

// MARK: - NetworkInfoViewDelegate

extension StakingMainViewController: NetworkInfoViewDelegate {
    func animateAlongsideWithInfo(view _: NetworkInfoView) {
        rootView.scrollView.layoutIfNeeded()
    }

    func didChangeExpansion(isExpanded: Bool, view _: NetworkInfoView) {
        presenter.networkInfoViewDidChangeExpansion(isExpanded: isExpanded)
    }
}

// MARK: - AlertsViewDelegate

extension StakingMainViewController: AlertsViewDelegate {
    func didSelectStakingAlert(_ alert: StakingAlert) {
        presenter.performAlertAction(alert)
    }
}

// MARK: - StakingActionsViewDelegate

extension StakingMainViewController: StakingActionsViewDelegate {
    func actionsViewDidSelectAction(_ action: StakingManageOption) {
        presenter.performManageAction(action)
    }
}

// MARK: - StakingUnbondingsViewDelegate

extension StakingMainViewController: StakingUnbondingsViewDelegate {
    func stakingUnbondingViewDidCancel(_: StakingUnbondingsView) {
        presenter.performRebondAction()
    }

    func stakingUnbondingViewDidRedeem(_: StakingUnbondingsView) {
        presenter.performRedeemAction()
    }
}
