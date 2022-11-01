import UIKit
import SoraFoundation

final class GovernanceUnlockSetupViewController: UIViewController, ViewHolder {
    typealias RootViewType = GovernanceUnlockSetupViewLayout

    let presenter: GovernanceUnlockSetupPresenterProtocol

    private var viewModel: GovernanceUnlocksViewModel?

    init(presenter: GovernanceUnlockSetupPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
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
}

extension GovernanceUnlockSetupViewController: GovernanceUnlockSetupViewProtocol {
    func didReceive(viewModel: GovernanceUnlocksViewModel) {
        self.viewModel = viewModel

        rootView.tableView.reloadData()
    }
}

extension GovernanceUnlockSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
