import UIKit
import UIKit_iOS
import Foundation_iOS

final class StakingMainViewLayout: UIView {
    private let ahmAlertLayoutChangesAnimator: BlockViewAnimatorProtocol = BlockViewAnimator(
        duration: 0.3,
        delay: 0.2,
        options: [.curveEaseInOut]
    )
    private let ahmAlertAppearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 0.0,
        to: 1.0,
        duration: 0.3,
        options: [.curveEaseInOut]
    )
    private let ahmAlertDisappearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 1.0,
        to: 0.0,
        duration: 0.3,
        options: [.curveEaseInOut]
    )

    let backgroundView = UIImageView.background

    let navBarBlurView: BlurBackgroundView = .create { view in
        view.cornerCut = []
    }

    var scrollView: UIScrollView { containerView.scrollView }
    var stackView: UIStackView { containerView.stackView }

    var networkInfoContainerView: UIView = .create { view in
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    var networkInfoView: NetworkInfoView = .create { view in
        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 343.0, height: 296))

        view.frame = defaultFrame
    }

    lazy var ahmAlertContainerView: UIView = .create { view in
        view.isHidden = true
    }

    lazy var ahmAlertView = AHMAlertView()

    var rewardContainerView: UIView?
    var rewardView: StakingRewardView?
    lazy var alertsContainerView = UIView()
    lazy var alertsView = AlertsView()

    var actionsView: StakingActionsView?
    var unbondingsView: StakingUnbondingsView?

    var selectedEntityView: StackTableView?
    var selectedEntityCell: StackAddressCell?

    var stateContainerView: UIView?
    var stateView: LocalizableView?

    var staticsViewModel: StakingMainStaticViewModelProtocol?

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        view.stackView.distribution = .fill
        view.stackView.spacing = 0.0
        return view
    }()

    var locale = Locale.current

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension StakingMainViewLayout {
    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        addSubview(navBarBlurView)
        navBarBlurView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top)
        }

        setupScrollView()
        setupNetworkInfoView()
        setupAlertsView()
    }

    func setupStakingRewardViewIfNeeded() {
        guard rewardContainerView == nil else {
            return
        }

        let containerView = UIView()

        let rewardView = StakingRewardView()
        rewardView.locale = locale

        containerView.addSubview(rewardView)

        applyConstraints(for: containerView, innerView: rewardView)

        stackView.insertArranged(view: containerView, after: alertsContainerView)

        rewardContainerView = containerView
        self.rewardView = rewardView
    }

    func setupNominatorViewIfNeeded() -> NominatorStateView? {
        if let nominatorView = stateView as? NominatorStateView {
            return nominatorView
        }

        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 343, height: 160.0))
        let stateView = setupView { NominatorStateView(frame: defaultFrame) }
        stateView?.locale = locale
        stateView?.statics = staticsViewModel

        return stateView
    }

    func setupValidatorViewIfNeeded() -> ValidatorStateView? {
        if let validator = stateView as? ValidatorStateView {
            return validator
        }

        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 343, height: 160.0))
        let stateView = setupView { ValidatorStateView(frame: defaultFrame) }
        stateView?.locale = locale
        stateView?.statics = staticsViewModel

        return stateView
    }

    func setupScrollView() {
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
    }

    func setupNetworkInfoView() {
        networkInfoContainerView.addSubview(networkInfoView)

        applyConstraints(for: networkInfoContainerView, innerView: networkInfoView)

        stackView.addArrangedSubview(networkInfoContainerView)
    }

    func setupAlertsView() {
        alertsContainerView.addSubview(alertsView)
        applyConstraints(for: alertsContainerView, innerView: alertsView)

        if ahmAlertContainerView.superview != nil {
            stackView.insertArranged(view: alertsContainerView, after: ahmAlertContainerView)
        } else {
            stackView.insertArrangedSubview(alertsContainerView, at: 0)
        }
    }

    func hideAHMAlertWithAnimation() {
        ahmAlertDisappearanceAnimator.animate(
            view: ahmAlertContainerView,
            completionBlock: nil
        )
        ahmAlertLayoutChangesAnimator.animate(
            block: { [weak self] in
                self?.ahmAlertContainerView.isHidden = true
                self?.stackView.layoutIfNeeded()
            },
            completionBlock: { [weak self] _ in
                self?.ahmAlertContainerView.removeFromSuperview()
            }
        )
    }

    func showAHMAlertWithAnimation() {
        ahmAlertContainerView.alpha = 0

        stackView.insertArrangedSubview(
            ahmAlertContainerView,
            at: 0
        )

        ahmAlertContainerView.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }

        ahmAlertLayoutChangesAnimator.animate(
            block: { [weak self] in
                guard let self else { return }

                ahmAlertContainerView.isHidden = false
                stackView.layoutIfNeeded()
            },
            completionBlock: { [weak self] _ in
                guard let self else { return }

                ahmAlertAppearanceAnimator.animate(
                    view: ahmAlertContainerView,
                    completionBlock: nil
                )
            }
        )
    }
}

// MARK: - Internal

extension StakingMainViewLayout {
    func setupEntityView(for viewModel: StakingSelectedEntityViewModel) {
        let entityView: StackTableView

        if let selectedEntityView = selectedEntityView {
            entityView = selectedEntityView
        } else {
            let containerView = UIView()

            entityView = StackTableView()

            stackView.insertArranged(view: containerView, before: networkInfoContainerView)

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

    func updateActionsView(
        for stakingActions: [StakingManageOption]?,
        delegate: StakingActionsViewDelegate
    ) {
        guard let stakingActions = stakingActions, !stakingActions.isEmpty else {
            actionsView?.removeFromSuperview()
            actionsView = nil

            return
        }

        if actionsView == nil {
            let newActionsView = StakingActionsView()
            newActionsView.locale = locale
            newActionsView.delegate = delegate
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

    func updateUnbondingsView(for unbondingViewModel: StakingUnbondingViewModel?) {
        guard let unbondingViewModel = unbondingViewModel, !unbondingViewModel.items.isEmpty else {
            unbondingsView?.removeFromSuperview()
            unbondingsView = nil

            return
        }

        if unbondingsView == nil {
            let newUnbondingsView = StakingUnbondingsView()
            newUnbondingsView.locale = locale

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

    func clearStateView() {
        if let containerView = stateContainerView {
            stackView.removeArrangedSubview(containerView)
            containerView.removeFromSuperview()
        }

        stateContainerView = nil
        stateView = nil
        alertsContainerView.isHidden = true
    }

    func clearStakingRewardViewIfNeeded() {
        rewardContainerView?.removeFromSuperview()
        rewardContainerView = nil
        rewardView = nil
    }

    func applyConstraints(for containerView: UIView, innerView: UIView) {
        innerView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(containerView).inset(UIConstants.horizontalInset)
            make.top.equalTo(containerView).offset(Constants.verticalSpacing)
            make.bottom.equalTo(containerView).offset(-Constants.bottomInset)
        }
    }

    func setupView<T: LocalizableView>(for viewFactory: () -> T?) -> T? {
        clearStateView()

        let containerView = UIView()

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

    func applyNominator(viewModel: LocalizableResource<NominationViewModel>) {
        let nominatorView = setupNominatorViewIfNeeded()
        nominatorView?.bind(viewModel: viewModel)
    }

    func applyValidator(viewModel: LocalizableResource<ValidationViewModel>) {
        let validatorView = setupValidatorViewIfNeeded()
        validatorView?.bind(viewModel: viewModel)
    }

    func applyAlerts(_ alerts: [StakingAlert]) {
        alertsContainerView.isHidden = alerts.isEmpty
        alertsView.bind(alerts: alerts)
        alertsContainerView.setNeedsLayout()
    }

    func applyStakingReward(viewModel: LocalizableResource<StakingRewardViewModel>) {
        setupStakingRewardViewIfNeeded()
        rewardView?.bind(viewModel: viewModel)
    }

    func setAHMAlert(with model: AHMAlertView.Model?) {
        if let model {
            guard ahmAlertContainerView.superview == nil else {
                ahmAlertView.bind(model)
                return
            }

            if ahmAlertView.superview == nil {
                ahmAlertContainerView.addSubview(ahmAlertView)
                applyConstraints(for: ahmAlertContainerView, innerView: ahmAlertView)
            }

            ahmAlertView.bind(model)

            showAHMAlertWithAnimation()
        } else {
            guard ahmAlertView.superview != nil else {
                return
            }

            hideAHMAlertWithAnimation()
        }
    }
}

// MARK: - Constants

private extension StakingMainViewLayout {
    enum Constants {
        static let verticalSpacing: CGFloat = 0.0
        static let bottomInset: CGFloat = 8.0
    }
}
