import UIKit
import SoraFoundation
import SoraUI

final class ReferendumSearchViewController: BaseTableSearchViewController {
    var presenter: ReferendumSearchPresenterProtocol? {
        basePresenter as? ReferendumSearchPresenterProtocol
    }

    private(set) var emptyStateType: EmptyState? = .start
    private var viewModels: [ReferendumsCellViewModel] = []

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
        applyState()
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
    }

    private func setupHandlers() {
        rootView.cancelButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
    }

    private func applyState() {
        rootView.tableView.isHidden = shouldDisplayEmptyState
        reloadEmptyState(animated: false)
    }

    private func setupTableView() {
        rootView.tableView.separatorStyle = .none
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(ReferendumTableViewCell.self)
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

    private func update(viewModels: [ReferendumsCellViewModel]) {
        guard viewModels != self.viewModels else {
            return
        }
        self.viewModels = viewModels
        rootView.tableView.reloadData()
    }
}

extension ReferendumSearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ReferendumTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        viewModels[safe: indexPath.row].map {
            cell.view.bind(viewModel: $0.viewModel)
            cell.applyStyle()
        }
        return cell
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }
}

extension ReferendumSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let referendumIndex = viewModels[safe: indexPath.row]?.referendumIndex else {
            return
        }

        presenter?.select(referendumIndex: referendumIndex)
    }
}

extension ReferendumSearchViewController: ReferendumSearchViewProtocol {
    func didReceive(viewModel: TableSearchResultViewModel<ReferendumsCellViewModel>) {
        switch viewModel {
        case .start:
            emptyStateType = .start
        case .notFound:
            emptyStateType = .notFound
        case let .found(_, viewModels):
            emptyStateType = nil
            update(viewModels: viewModels)
        }

        applyState()
    }

    func updateReferendums(time: [UInt: StatusTimeViewModel?]) {
        rootView.tableView.visibleCells.forEach { cell in
            guard let referendumCell = cell as? ReferendumTableViewCell,
                  let indexPath = rootView.tableView.indexPath(for: cell),
                  let cellModel = viewModels[safe: indexPath.row] else {
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
