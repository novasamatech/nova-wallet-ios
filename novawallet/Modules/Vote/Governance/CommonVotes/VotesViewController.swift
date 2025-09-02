import UIKit
import Foundation_iOS
import UIKit_iOS

final class VotesViewController: UIViewController, ViewHolder {
    typealias RootViewType = VotesViewLayout

    private let quantityFormatter: LocalizableResource<NumberFormatter>
    private var state: LoadableViewModelState<[VotesViewModel]>?
    private var localizableTitle: LocalizableResource<String>?
    private var emptyViewTitle: LocalizableResource<String>?

    let presenter: VotesPresenterProtocol

    init(
        presenter: VotesPresenterProtocol,
        quantityFormatter: LocalizableResource<NumberFormatter>,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.quantityFormatter = quantityFormatter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = VotesViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        configureTableView()
        setupHandlers()

        presenter.setup()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        switch state {
        case .loading:
            rootView.updateLoadingState()
        case .loaded, .cached, .none:
            break
        }
    }

    private func configureTableView() {
        rootView.tableView.registerClassForCell(VotesTableViewCell.self)
        rootView.tableView.delegate = self
        rootView.tableView.dataSource = self
        rootView.tableView.rowHeight = VotesTableViewCell.Constants.rowHeight
    }

    private func setupCounter(value: Int?) {
        navigationItem.rightBarButtonItem = nil

        let formatter = quantityFormatter.value(for: selectedLocale)

        guard
            let value = value,
            let valueString = formatter.string(from: value as NSNumber) else {
            return
        }

        rootView.totalVotersLabel.titleLabel.text = valueString
        rootView.totalVotersLabel.sizeToFit()

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rootView.totalVotersLabel)
    }

    private func setupLocalization() {
        title = localizableTitle?.value(for: selectedLocale)
    }

    private func setupHandlers() {
        rootView.refreshControl.addTarget(
            self,
            action: #selector(pullToRefreshAction),
            for: .valueChanged
        )
    }

    @objc private func pullToRefreshAction() {
        rootView.refreshControl.endRefreshing()
        presenter.refresh()
    }
}

extension VotesViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        state?.value?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: VotesTableViewCell = tableView.dequeueReusableCell(for: indexPath)

        if let viewModel = state?.value?[indexPath.row] {
            cell.bind(viewModel: viewModel)
        }

        return cell
    }
}

extension VotesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let viewModels = state?.value else {
            return
        }

        presenter.select(viewModel: viewModels[indexPath.row])
    }
}

extension VotesViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
    var contentViewForEmptyState: UIView { rootView }
}

extension VotesViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyStateView()
        emptyView.image = R.image.iconEmptyHistory()
        emptyView.title = emptyViewTitle?.value(for: selectedLocale) ?? ""
        emptyView.titleColor = R.color.colorTextSecondary()!
        emptyView.titleFont = .regularFootnote
        return emptyView
    }
}

extension VotesViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        switch state {
        case let .loaded(value), let .cached(value):
            return value.isEmpty
        case .loading, .none:
            return false
        }
    }
}

extension VotesViewController: VotesViewProtocol {
    func didReceiveViewModels(_ viewModels: LoadableViewModelState<[VotesViewModel]>) {
        state = viewModels
        rootView.tableView.reloadData()

        setupCounter(value: viewModels.value?.count)

        switch viewModels {
        case .loading:
            rootView.startLoadingIfNeeded()
        case .loaded, .cached:
            rootView.stopLoadingIfNeeded()
        }

        reloadEmptyState(animated: false)
    }

    func didReceive(title: LocalizableResource<String>) {
        localizableTitle = title
        setupLocalization()
    }

    func didReceiveEmptyView(title: LocalizableResource<String>) {
        emptyViewTitle = title
    }

    func didReceiveRefreshState(isAvailable: Bool) {
        rootView.updateRefreshControlState(isAvailable: isAvailable)
    }
}

extension VotesViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
