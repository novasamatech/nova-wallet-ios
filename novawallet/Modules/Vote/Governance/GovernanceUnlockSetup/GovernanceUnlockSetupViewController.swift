import UIKit
import Foundation_iOS

final class GovernanceUnlockSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = GovernanceUnlockSetupViewLayout

    let presenter: GovernanceUnlockSetupPresenterProtocol

    private var viewModel: GovernanceUnlocksViewModel?

    init(presenter: GovernanceUnlockSetupPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = GovernanceUnlockSetupViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupTableView()
        setupHandlers()
        updateUnlockState()

        presenter.setup()
    }

    private func setupTableView() {
        rootView.tableView.registerClassForCell(GovernanceUnlockTableViewCell.self)
        rootView.tableView.registerClassForCell(CrowdloanYourContributionsTotalCell.self)

        rootView.tableView.dataSource = self
    }

    private func setupHandlers() {
        rootView.unlockButton.addTarget(
            self,
            action: #selector(actionUnlock),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        title = R.string.localizable.walletBalanceLocked(preferredLanguages: selectedLocale.rLanguages)

        rootView.unlockButton.imageWithTitleView?.title = R.string.localizable.commonUnlock(
            preferredLanguages: selectedLocale.rLanguages
        )
        rootView.unlockButton.invalidateLayout()
    }

    private func updateUnlockState() {
        let hasUnlockable = viewModel?.items.contains {
            switch $0.claimState {
            case .now:
                return true
            case .afterPeriod, .delegation:
                return false
            }
        } ?? false

        if hasUnlockable {
            rootView.unlockButton.applyEnabledStyle()
        } else {
            rootView.unlockButton.applyDisabledStyle()
        }

        rootView.unlockButton.isUserInteractionEnabled = hasUnlockable
    }

    @objc private func actionUnlock() {
        presenter.unlock()
    }
}

extension GovernanceUnlockSetupViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel != nil ? 2 : 0
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else {
            return 0
        }

        if section == 0 {
            return 1
        } else {
            return viewModel.items.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCellWithType(
                CrowdloanYourContributionsTotalCell.self,
                forIndexPath: indexPath
            )

            cell.view.apply(style: .readonly)
            cell.view.bind(
                model: .init(
                    title: R.string.localizable.crowdloanYouContributionsTotal(
                        preferredLanguages: selectedLocale.rLanguages
                    ),
                    count: nil,
                    amount: viewModel?.total.amount ?? "",
                    amountDetails: viewModel?.total.price ?? ""
                )
            )

            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithType(
                GovernanceUnlockTableViewCell.self,
                forIndexPath: indexPath
            )

            if let viewModel = viewModel {
                cell.bind(viewModel: viewModel.items[indexPath.row], locale: selectedLocale)
            }

            return cell
        }
    }

    private func applyClaimStates() {
        guard let items = viewModel?.items else {
            return
        }

        let visibleIndexPaths = rootView.tableView.indexPathsForVisibleRows?.filter { $0.section > 0 } ?? []

        visibleIndexPaths.forEach { indexPath in
            guard let cell = rootView.tableView.cellForRow(at: indexPath) as? GovernanceUnlockTableViewCell else {
                return
            }

            cell.bind(claimState: items[indexPath.row].claimState, locale: selectedLocale)
        }
    }
}

extension GovernanceUnlockSetupViewController: GovernanceUnlockSetupViewProtocol {
    func didReceive(viewModel: GovernanceUnlocksViewModel) {
        self.viewModel = viewModel

        rootView.tableView.reloadData()

        updateUnlockState()
    }

    func didTickClaim(states: [GovernanceUnlocksViewModel.ClaimState]) {
        guard let viewModel = viewModel else {
            return
        }

        let newItems = zip(states, viewModel.items).map {
            GovernanceUnlocksViewModel.Item(amount: $0.1.amount, claimState: $0.0)
        }

        self.viewModel = .init(total: viewModel.total, items: newItems)

        applyClaimStates()
        updateUnlockState()
    }
}

extension GovernanceUnlockSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
