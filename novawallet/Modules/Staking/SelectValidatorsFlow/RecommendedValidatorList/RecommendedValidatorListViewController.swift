import UIKit
import SoraFoundation

final class RecommendedValidatorListViewController: UIViewController, ViewHolder {
    typealias RootViewType = SelectedValidatorListViewLayout

    let presenter: RecommendedValidatorListPresenterProtocol

    private var viewModel: RecommendedValidatorListViewModelProtocol?

    init(
        presenter: RecommendedValidatorListPresenterProtocol,
        localizationManager: LocalizationManagerProtocol? = nil
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
        view = SelectedValidatorListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    private func setupTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(SelectedValidatorCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: SelectedValidatorListHeaderView.self)
    }

    private func setupHandlers() {
        rootView.proceedButton.addTarget(
            self,
            action: #selector(actionContinue),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        title = R.string.localizable.stakingRecommendedSectionTitle(preferredLanguages: languages)

        rootView.proceedButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
            preferredLanguages: languages
        )
    }

    @objc private func actionContinue() {
        presenter.proceed()
    }
}

extension RecommendedValidatorListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.itemViewModels.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(SelectedValidatorCell.self)!

        let items = viewModel?.itemViewModels ?? []
        let viewModel = items[indexPath.row].value(for: selectedLocale)
        cell.bind(viewModel: viewModel)

        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let viewModel = viewModel else {
            return nil
        }

        let headerView: SelectedValidatorListHeaderView = tableView.dequeueReusableHeaderFooterView()

        let languages = selectedLocale.rLanguages
        let title = viewModel.itemsCountString.value(for: selectedLocale)

        let details = R.string.localizable.stakingFilterTitleRewards(preferredLanguages: languages)

        headerView.bind(title: title, details: details)

        return headerView
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter.selectedValidatorAt(index: indexPath.row)
    }
}

extension RecommendedValidatorListViewController: RecommendedValidatorListViewProtocol {
    func didReceive(viewModel: RecommendedValidatorListViewModelProtocol) {
        self.viewModel = viewModel

        rootView.tableView.reloadData()
    }
}

extension RecommendedValidatorListViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            rootView.tableView.reloadData()
            view.setNeedsLayout()
        }
    }
}
