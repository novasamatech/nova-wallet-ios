import UIKit
import SoraFoundation

final class CrowdloanYourContributionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanYourContributionsViewLayout

    let presenter: CrowdloanYourContributionsPresenterProtocol

    private var viewModel: CrowdloanYourContributionsViewModel?
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
        rootView.tableView.registerClassForCell(CrowdloanYourContributionsTotalCell.self)
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

// MARK: - CrowdloanYourContributionsViewProtocol

extension CrowdloanYourContributionsViewController: CrowdloanYourContributionsViewProtocol {
    func reload(model: CrowdloanYourContributionsViewModel) {
        viewModel = model
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

// MARK: - Localizable

extension CrowdloanYourContributionsViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable
                .crowdloanYouContributionsTitle(preferredLanguages: selectedLocale.rLanguages)
        }
    }
}

// MARK: - UITableViewDataSource

extension CrowdloanYourContributionsViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel?.sections.count ?? 0
    }

    func tableView(_: UITableView, numberOfRowsInSection: Int) -> Int {
        switch viewModel?.sections[numberOfRowsInSection] {
        case .total:
            return 1
        case let .contributions(contributions):
            return contributions.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel?.sections[indexPath.section] {
        case let .total(model):
            let cell: CrowdloanYourContributionsTotalCell = tableView.dequeueReusableCell(for: indexPath)
            cell.view.bind(model: model)
            return cell
        case let .contributions(contributions):
            let contribution = contributions[indexPath.row]
            let cell: CrowdloanYourContributionsCell = tableView.dequeueReusableCell(for: indexPath)
            cell.bind(contributionViewModel: contribution)
            bindReturnInInterval(to: cell, at: indexPath)
            return cell
        default:
            return UITableViewCell()
        }
    }
}

// MARK: - UITableViewDelegate

extension CrowdloanYourContributionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
