import UIKit
import SoraFoundation
import SwiftUI

final class DAppSearchViewController: UIViewController, ViewHolder {
    typealias RootViewType = DAppSearchViewLayout

    let presenter: DAppSearchPresenterProtocol

    private var searchTitle: String?

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

    private func sectionCount(for title: String?) -> Int {
        (title ?? "").isEmpty ? 0 : 1
    }

    @objc private func actionTextFieldChanged() {
        let oldSectionCount = sectionCount(for: searchTitle)
        searchTitle = rootView.searchBar.textField.text

        let newSectionCount = sectionCount(for: searchTitle)

        if oldSectionCount != newSectionCount {
            rootView.tableView.reloadData()
        } else {
            rootView.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
        }

        presenter.updateSearch(query: searchTitle ?? "")
    }

    @objc func actionCancel() {
        presenter.cancel()
    }
}

extension DAppSearchViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        sectionCount(for: searchTitle)
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, cellForRowAt _: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithType(DAppSearchQueryTableViewCell.self)!
        cell.bind(title: searchTitle ?? "")
        return cell
    }
}

extension DAppSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter.selectSearchQuery()
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
}

extension DAppSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            rootView.tableView.reloadData()
        }
    }
}
