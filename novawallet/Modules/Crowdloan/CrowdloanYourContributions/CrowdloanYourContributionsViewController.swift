import UIKit
import SoraFoundation

final class CrowdloanYourContributionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanYourContributionsViewLayout

    let presenter: CrowdloanYourContributionsPresenterProtocol

    private var contributions: [CrowdloanContributionViewModel]?
    private var returnInTimeIntervals: [String?]?

    init(
        presenter: CrowdloanYourContributionsPresenterProtocol,
        localizationManager: LocalizationManagerProtocol?
    ) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = CrowdloanYourContributionsViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        applyLocalization()
        presenter.setup()
    }

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(CrowdloanYourContributionsCell.self)
    }

    private func bindReturnInInterval(to cell: CrowdloanYourContributionsCell, at indexPath: IndexPath) {
        guard
            let returnInTimeIntervals = returnInTimeIntervals,
            indexPath.row < returnInTimeIntervals.count else {
            return
        }

        let subtitle: String

        if let returnIn = returnInTimeIntervals[indexPath.row] {
            subtitle = R.string.localizable.crowdloanReturnsInFormat(
                returnIn,
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            subtitle = R.string.localizable.crowdloanReturnInProgress(preferredLanguages: selectedLocale.rLanguages)
        }

        cell.bind(returnInViewModel: subtitle)
    }
}

extension CrowdloanYourContributionsViewController: CrowdloanYourContributionsViewProtocol {
    func reload(contributions: [CrowdloanContributionViewModel]) {
        self.contributions = contributions
        rootView.tableView.reloadData()
    }

    func reload(returnInIntervals: [String?]) {
        returnInTimeIntervals = returnInIntervals

        rootView.tableView.visibleCells.forEach { cell in
            guard
                let indexPath = rootView.tableView.indexPath(for: cell),
                let contributionCell = cell as? CrowdloanYourContributionsCell else {
                return
            }

            bindReturnInInterval(to: contributionCell, at: indexPath)
        }
    }
}

extension CrowdloanYourContributionsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .crowdloanYouContributionsTitle(preferredLanguages: selectedLocale.rLanguages)
        }
    }
}

extension CrowdloanYourContributionsViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        contributions?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let contributions = contributions else { return UITableViewCell() }
        let contribution = contributions[indexPath.row]
        let cell = tableView.dequeueReusableCellWithType(CrowdloanYourContributionsCell.self)!
        cell.bind(contributionViewModel: contribution)

        bindReturnInInterval(to: cell, at: indexPath)

        return cell
    }
}

extension CrowdloanYourContributionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
