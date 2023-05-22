import UIKit
import SoraFoundation
import SoraUI

final class ReferendumSearchViewController: BaseTableSearchViewController {
    var presenter: ReferendumSearchPresenterProtocol? {
        basePresenter as? ReferendumSearchPresenterProtocol
    }

    private var viewModel: TableSearchResultViewModel<ReferendumsCellViewModel> = .start

    init(presenter: ReferendumSearchPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        super.init(basePresenter: presenter)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        setupTableView()
        setupSearchView()
        applyLocalization()
        setupHandlers()

        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        rootView.searchView.searchBar.becomeFirstResponder()
    }

    private func setupSearchView() {
        rootView.apply(style: .init(
            background: .multigradient,
            contentInsets: .init(top: 16, left: 0, bottom: 0, right: 0)
        ))
        rootView.cancelButton.isHidden = false
        rootView.cancelButton.contentInsets = .init(top: 0, left: 16, bottom: 0, right: 16)
    }

    private func setupLocalization() {
        title = ""

        rootView.searchField.placeholder = R.string.localizable.governanceReferendumsSearchFieldPlaceholder(
            preferredLanguages: selectedLocale.rLanguages
        )

        let cancelButtonTitle = R.string.localizable.commonCancel(preferredLanguages: selectedLocale.rLanguages)
        rootView.cancelButton.imageWithTitleView?.title = cancelButtonTitle

        rootView.tableView.reloadData()
    }

    private func setupHandlers() {
        rootView.cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
    }

    private func setupTableView() {
        rootView.tableView.separatorStyle = .none
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(ReferendumTableViewCell.self)
        rootView.tableView.registerClassForCell(ReferendumEmptySearchTableViewCell.self)
    }

    private func updateTime(
        in model: ReferendumView.Model,
        time: StatusTimeViewModel??
    ) -> ReferendumView.Model {
        var updatingValue = model
        updatingValue.referendumInfo.time = time??.viewModel
        return updatingValue
    }

    @objc
    private func cancelAction() {
        presenter?.cancel()
    }

    private func referendumTableViewCell(
        _ tableView: UITableView,
        indexPath: IndexPath,
        model: ReferendumsCellViewModel?
    ) -> ReferendumTableViewCell {
        let cell: ReferendumTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        model.map {
            cell.view.bind(viewModel: $0.viewModel)
            cell.applyStyle()
        }
        return cell
    }

    private func emptyTableViewCell(
        _ tableView: UITableView,
        indexPath: IndexPath
    ) -> ReferendumEmptySearchTableViewCell {
        let cell: ReferendumEmptySearchTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        let text = R.string.localizable.governanceReferendumsSearchEmpty(
            preferredLanguages: selectedLocale.rLanguages)
        cell.bind(text: text)
        return cell
    }
}

extension ReferendumSearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel {
        case .start:
            return UITableViewCell()
        case .notFound:
            return emptyTableViewCell(tableView, indexPath: indexPath)
        case let .found(_, items):
            return referendumTableViewCell(tableView, indexPath: indexPath, model: items[safe: indexPath.row])
        }
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        switch viewModel {
        case .start:
            return 0
        case .notFound:
            return 1
        case let .found(_, items):
            return items.count
        }
    }
}

extension ReferendumSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .found(_, referendums) = viewModel,
              let referendumIndex = referendums[safe: indexPath.row]?.referendumIndex else {
            return
        }

        presenter?.select(referendumIndex: referendumIndex)
    }
}

extension ReferendumSearchViewController: ReferendumSearchViewProtocol {
    func didReceive(viewModel: TableSearchResultViewModel<ReferendumsCellViewModel>) {
        switch (viewModel, self.viewModel) {
        case (.start, .start):
            return
        case (.notFound, .notFound):
            return
        case let (.found(newTitle, newItems), .found(oldTitle, oldItems)):
            if newTitle == oldTitle, newItems == oldItems {
                return
            }
        default:
            break
        }

        self.viewModel = viewModel
        rootView.tableView.reloadData()
    }

    func updateReferendums(time: [UInt: StatusTimeViewModel?]) {
        guard case let .found(_, referendums) = viewModel else {
            return
        }
        rootView.tableView.visibleCells.forEach { cell in
            guard let referendumCell = cell as? ReferendumTableViewCell,
                  let indexPath = rootView.tableView.indexPath(for: cell),
                  let cellModel = referendums[safe: indexPath.row] else {
                return
            }

            guard let timeModel = time[cellModel.referendumIndex]??.viewModel else {
                return
            }

            referendumCell.view.referendumInfoView.bind(timeModel: timeModel)
        }
    }
}

extension ReferendumSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
