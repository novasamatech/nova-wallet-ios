import UIKit
import Foundation_iOS
import SwiftUI

final class DAppSearchViewController: UIViewController, ViewHolder {
    enum Section {
        case search
        case dapps

        static func section(for index: Int, searchTitle: String?) -> Section {
            guard index == 0 else {
                return .dapps
            }

            if let searchTitle = searchTitle, !searchTitle.isEmpty {
                return .search
            } else {
                return .dapps
            }
        }

        static func numberOfSections(for searchTitle: String?, viewModel: DAppListViewModel?) -> Int {
            if
                let searchTitle = searchTitle,
                let viewModel,
                !viewModel.dApps.isEmpty,
                !searchTitle.isEmpty {
                return 2
            } else {
                return 1
            }
        }
    }

    typealias RootViewType = DAppSearchViewLayout

    let presenter: DAppSearchPresenterProtocol

    private var searchTitle: String?
    private var viewModel: DAppListViewModel?

    init(presenter: DAppSearchPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = DAppSearchViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupSearchBar()
        setupCategoriesBar()
        setupLocalization()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        rootView.searchBar.textField.becomeFirstResponder()
    }
}

// MARK: Private

private extension DAppSearchViewController {
    func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.searchBar.textField.placeholder = R.string(preferredLanguages: languages).localizable.dappListSearch()

        rootView.cancelBarItem.title = R.string(preferredLanguages: languages).localizable.commonCancel()
    }

    func setupTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.tableView.registerClassForCell(DAppSearchQueryTableViewCell.self)
        rootView.tableView.registerClassForCell(DAppItemTableViewCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: DAppSearchHeaderView.self)
    }

    func setupSearchBar() {
        navigationItem.titleView = rootView.searchBar
        navigationItem.rightBarButtonItem = rootView.cancelBarItem

        rootView.searchBar.textField.addTarget(
            self,
            action: #selector(actionTextFieldChanged),
            for: .editingChanged
        )

        rootView.searchBar.textField.delegate = self
        rootView.searchBar.textField.returnKeyType = .done

        rootView.cancelBarItem.target = self
        rootView.cancelBarItem.action = #selector(actionCancel)
    }

    func setupCategoriesBar() {
        rootView.categoriesView.delegate = self
    }

    @objc func actionTextFieldChanged() {
        let oldSectionCount = Section.numberOfSections(
            for: searchTitle,
            viewModel: viewModel
        )

        searchTitle = rootView.searchBar.textField.text

        let newSectionCount = Section.numberOfSections(
            for: searchTitle,
            viewModel: viewModel
        )

        if oldSectionCount != newSectionCount {
            rootView.tableView.reloadData()
        } else {
            rootView.tableView.reloadSections([0], with: .none)
        }

        presenter.updateSearch(query: searchTitle ?? "")
    }

    @objc func actionCancel() {
        presenter.cancel()
    }
}

// MARK: UITableViewDataSource

extension DAppSearchViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        Section.numberOfSections(
            for: searchTitle,
            viewModel: viewModel
        )
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section.section(for: section, searchTitle: searchTitle) {
        case .search: 1
        case .dapps: viewModel?.dApps.count ?? 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = Section.section(
            for: indexPath.section,
            searchTitle: searchTitle
        )

        switch section {
        case .search:
            let cell = tableView.dequeueReusableCellWithType(DAppSearchQueryTableViewCell.self)!
            cell.bind(title: searchTitle ?? "")
            return cell
        case .dapps:
            guard
                indexPath.row < viewModel?.dApps.count ?? 0,
                let dAppViewModel = viewModel?.dApps[indexPath.row]
            else {
                return UITableViewCell()
            }

            let cell: DAppItemTableViewCell = tableView.dequeueReusableCellWithType(DAppItemTableViewCell.self)!
            cell.contentDisplayView.bind(viewModel: dAppViewModel)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let tableSection = Section.section(
            for: section,
            searchTitle: searchTitle
        )

        let view: DAppSearchHeaderView = tableView.dequeueReusableHeaderFooterView()

        let title: String

        switch tableSection {
        case .search:
            title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.dappSearchQuerySection()
        case .dapps:
            title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.dappListFeaturedWebsites()
        }

        view.bind(title: title)

        return view
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        40.0
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        64.0
    }
}

// MARK: UITableViewDelegate

extension DAppSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let tableSection = Section.section(
            for: indexPath.section,
            searchTitle: searchTitle
        )

        switch tableSection {
        case .search:
            presenter.selectSearchQuery()
        case .dapps:
            guard let dAppViewModel = viewModel?.dApps[indexPath.row] else { return }

            presenter.selectDApp(viewModel: dAppViewModel)
        }
    }
}

// MARK: UITextFieldDelegate

extension DAppSearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// MARK: DAppCategoriesViewDelegate

extension DAppSearchViewController: DAppCategoriesViewDelegate {
    func dAppCategories(
        view _: DAppCategoriesView,
        didSelectCategoryWith identifier: String?
    ) {
        presenter.selectCategory(with: identifier)
    }
}

// MARK: DAppSearchViewProtocol

extension DAppSearchViewController: DAppSearchViewProtocol {
    func didReceive(initialQuery: String) {
        searchTitle = initialQuery
        rootView.searchBar.textField.text = initialQuery

        rootView.tableView.reloadData()
    }

    func didReceive(viewModel: DAppListViewModel?) {
        self.viewModel = viewModel

        rootView.categoriesView.bind(categories: viewModel?.categories ?? [])

        rootView.categoriesView.setSelectedIndex(
            viewModel?.selectedCategoryIndex,
            animated: true
        )

        rootView.tableView.reloadData()
    }
}

// MARK: Localizable

extension DAppSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            rootView.tableView.reloadData()
        }
    }
}
