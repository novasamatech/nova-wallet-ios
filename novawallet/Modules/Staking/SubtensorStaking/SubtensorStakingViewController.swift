import UIKit

/// Main TAO staking dashboard, scoped to the entry netuid (root or a
/// specific subnet). Layout: Your stake total → Stake/Unstake action list
/// → Your validator(s) card → Staking info expandable footer.
final class SubtensorStakingViewController: UIViewController, SubtensorStakingViewProtocol {
    private let presenter: SubtensorStakingPresenterProtocol
    private let rootView = SubtensorStakingViewLayout()

    var controller: UIViewController { self }

    init(presenter: SubtensorStakingPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func loadView() {
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "TAO Staking"
        rootView.showState(.loading)
        wireActions()
        presenter.setup()
    }

    private var hasAppeared = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Initial load is driven by `setup()` from viewDidLoad. Subsequent
        // appearances (e.g. popping back from the stake confirm flow) need
        // a refresh so the new position lands without making the user
        // reopen the screen.
        if hasAppeared {
            presenter.refresh()
        } else {
            hasAppeared = true
        }
    }

    private func wireActions() {
        rootView.startStakingButton.addTarget(
            self,
            action: #selector(didTapStakeMore),
            for: .touchUpInside
        )
        rootView.stakeMoreCell.addTarget(
            self,
            action: #selector(didTapStakeMore),
            for: .touchUpInside
        )
        rootView.unstakeCell.addTarget(
            self,
            action: #selector(didTapUnstake),
            for: .touchUpInside
        )
    }

    // MARK: - Actions

    @objc private func didTapStakeMore() {
        presenter.didTapStakeMore()
    }

    @objc private func didTapUnstake() {
        presenter.didTapUnstake()
    }

    // MARK: - SubtensorStakingViewProtocol

    func didReceive(viewModel: SubtensorStakingDashboardViewModel) {
        guard let totalRow = viewModel.totalStakeRow else {
            rootView.showState(.empty)
            return
        }

        rootView.stakeCardView.bind(title: "Your stake", rows: [totalRow])

        rootView.stakeMoreCell.bind(
            title: "Stake more",
            icon: R.image.iconBondMore(),
            details: nil
        )
        rootView.unstakeCell.bind(
            title: "Unstake",
            icon: R.image.iconUnbond(),
            details: nil
        )

        rootView.validatorListView.bind(
            title: viewModel.validatorsTitle,
            rows: viewModel.validatorRows
        )
        rootView.validatorListView.isHidden = viewModel.validatorRows.isEmpty

        rootView.stakingInfoView.bind(model: viewModel.info)

        rootView.showState(.loaded)
    }
}
