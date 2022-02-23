import UIKit
import SoraFoundation
import SwiftUI

final class DAppSearchViewController: UIViewController, ViewHolder {
    enum Section {
        case search
        case dapps

        static func section(for index: Int, searchTitle: String?, viewModels _: [DAppViewModel]) -> Section {
            guard index == 0 else {
                return .dapps
            }

            if let searchTitle = searchTitle, !searchTitle.isEmpty {
                return .search
            } else {
                return .dapps
            }
        }

        static func numberOfSections(for searchTitle: String?, viewModels: [DAppViewModel]) -> Int {
            if let searchTitle = searchTitle, !searchTitle.isEmpty, !viewModels.isEmpty {
                return 2
            } else {
                return 1
            }
        }
    }

    typealias RootViewType = DAppSearchViewLayout

    let presenter: DAppSearchPresenterProtocol

    private var searchTitle: String?
    private var viewModels: [DAppViewModel] = []

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
        setupLocalization()

        presenter.setup()
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages
        rootView.searchBar.textField.placeholder = R.string.localizable.dappListSearch(
            preferredLanguages: languages
        )

        rootView.cancelBarItem.title = R.string.localizable.commonCancel(preferredLanguages: languages)
    }

    private func setupTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self

        rootView.tableView.registerClassForCell(DAppSearchQueryTableViewCell.self)
        rootView.tableView.registerClassForCell(DAppSearchDAppTableViewCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: DAppSearchHeaderView.self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        rootView.searchBar.textField.becomeFirstResponder()
    }

    private func setupSearchBar() {
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

    @objc private func actionTextFieldChanged() {
        let oldSectionCount = Section.numberOfSections(for: searchTitle, viewModels: viewModels)
        searchTitle = rootView.searchBar.textField.text

        let newSectionCount = Section.numberOfSections(for: searchTitle, viewModels: viewModels)

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

extension DAppSearchViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        Section.numberOfSections(for: searchTitle, viewModels: viewModels)
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section.section(for: section, searchTitle: searchTitle, viewModels: viewModels) {
        case .search:
            return 1
        case .dapps:
            return viewModels.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = Section.section(
            for: indexPath.section,
            searchTitle: searchTitle,
            viewModels: viewModels
        )

        switch section {
        case .search:
            let cell = tableView.dequeueReusableCellWithType(DAppSearchQueryTableViewCell.self)!
            cell.bind(title: searchTitle ?? "")
            return cell
        case .dapps:
            let cell = tableView.dequeueReusableCellWithType(DAppSearchDAppTableViewCell.self)!
            cell.bind(viewModel: viewModels[indexPath.row])
            return cell
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let tableSection = Section.section(
            for: section,
            searchTitle: searchTitle,
            viewModels: viewModels
        )

        let view: DAppSearchHeaderView = tableView.dequeueReusableHeaderFooterView()

        let title: String

        switch tableSection {
        case .search:
            title = R.string.localizable.dappSearchQuerySection(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .dapps:
            title = R.string.localizable.dappListFeaturedWebsites(
                preferredLanguages: selectedLocale.rLanguages
            )
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

extension DAppSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let tableSection = Section.section(
            for: indexPath.section,
            searchTitle: searchTitle,
            viewModels: viewModels
        )

        switch tableSection {
        case .search:
            presenter.selectSearchQuery()
        case .dapps:
            presenter.selectDApp(viewModel: viewModels[indexPath.row])
        }
    }
}

extension DAppSearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

extension DAppSearchViewController: DAppSearchViewProtocol {
    func didReceive(initialQuery: String) {
        searchTitle = initialQuery
        rootView.searchBar.textField.text = initialQuery

        rootView.tableView.reloadData()
    }

    func didReceiveDApp(viewModels: [DAppViewModel]) {
        self.viewModels = viewModels

        rootView.tableView.reloadData()
    }
}

extension DAppSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            rootView.tableView.reloadData()
        }
    }
}
