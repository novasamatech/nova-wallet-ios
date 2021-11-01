import UIKit
import SoraFoundation

final class CrowdloanYourContributionsViewController: UIViewController, ViewHolder {
    typealias RootViewType = CrowdloanYourContributionsViewLayout

    let presenter: CrowdloanYourContributionsPresenterProtocol

    private var contributions: [CrowdloanContributionViewModel]?

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

        navigationController?.navigationBar.prefersLargeTitles = true
        setupTable()
        applyLocalization()
        presenter.setup()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(CrowdloanYourContributionsCell.self)
    }
}

extension CrowdloanYourContributionsViewController: CrowdloanYourContributionsViewProtocol {
    func reload(contributions: [CrowdloanContributionViewModel]) {
        self.contributions = contributions
        rootView.tableView.reloadData()
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
        cell.bind(viewModel: contribution)
        return cell
    }
}

extension CrowdloanYourContributionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
