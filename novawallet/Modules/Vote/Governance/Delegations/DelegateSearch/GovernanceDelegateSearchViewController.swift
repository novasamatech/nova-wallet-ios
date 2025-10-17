import UIKit
import Foundation_iOS
import UIKit_iOS

final class GovernanceDelegateSearchViewController: BaseTableSearchViewController {
    enum EmptyStateType {
        case notFound
        case start
    }

    var presenter: GovernanceDelegateSearchPresenterProtocol? {
        basePresenter as? GovernanceDelegateSearchPresenterProtocol
    }

    typealias DataSource = UITableViewDiffableDataSource<TitleWithSubtitleViewModel, AddDelegationViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<TitleWithSubtitleViewModel, AddDelegationViewModel>
    private lazy var dataSource = createDataSource()

    private var headerViewModel: TitleWithSubtitleViewModel?
    private var emptyStateType: EmptyStateType? = .start

    init(presenter: GovernanceDelegateSearchPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        super.init(basePresenter: presenter)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        setupTableView()
        applyLocalization()
        applyState()

        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        rootView.searchView.searchBar.becomeFirstResponder()
    }

    private func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSearch()

        rootView.searchField.placeholder = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.searchByAddressNamePlaceholder()
    }

    private func applyState() {
        rootView.tableView.isHidden = shouldDisplayEmptyState
        reloadEmptyState(animated: false)
    }

    private func setupTableView() {
        rootView.tableView.separatorStyle = .none
        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self

        rootView.tableView.registerClassForCell(GovernanceDelegateTableViewCell.self)
        rootView.tableView.registerClassForCell(GovernanceYourDelegationCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: CustomValidatorListHeaderView.self)
    }

    private func createDataSource() -> DataSource {
        let dataSource: DataSource = .init(
            tableView: rootView.tableView
        ) { [weak self] tableView, indexPath, model -> UITableViewCell? in
            guard let self = self else {
                return nil
            }

            switch model {
            case let .delegate(viewModel):
                let cell: GovernanceDelegateTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.bind(viewModel: viewModel, locale: self.selectedLocale)
                cell.applyStyle()

                return cell
            case let .yourDelegate(viewModel):
                let cell: GovernanceYourDelegationCell = tableView.dequeueReusableCell(for: indexPath)
                cell.bind(viewModel: viewModel, locale: self.selectedLocale)
                return cell
            }
        }

        return dataSource
    }
}

extension GovernanceDelegateSearchViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        guard headerViewModel != nil else { return 0 }

        return 29
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let headerViewModel = headerViewModel else {
            return nil
        }

        let headerView: CustomValidatorListHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.bind(viewModel: headerViewModel)
        return headerView
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let selectedItem = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        presenter?.presentResult(for: selectedItem.address)
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension GovernanceDelegateSearchViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension GovernanceDelegateSearchViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        guard let emptyStateType = emptyStateType else {
            return nil
        }

        let emptyView = EmptyStateView()

        switch emptyStateType {
        case .notFound:
            emptyView.image = R.image.iconEmptySearch()
            emptyView.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.walletSearchEmptyTitle_v1100()
        case .start:
            emptyView.image = R.image.iconStartSearch()
            emptyView.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonSearchStartTitle_v2_2_0()
        }

        emptyView.titleColor = R.color.colorTextSecondary()!
        emptyView.titleFont = .p2Paragraph

        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.contentView
    }

    var verticalSpacingForEmptyState: CGFloat? { 0 }
}

// MARK: - EmptyStateDelegate

extension GovernanceDelegateSearchViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        emptyStateType != nil
    }
}

extension GovernanceDelegateSearchViewController: GovernanceDelegateSearchViewProtocol {
    func didReceive(viewModel: TableSearchResultViewModel<AddDelegationViewModel>) {
        var snapshot = Snapshot()

        if let items = viewModel.items, let headerViewModel = viewModel.title {
            self.headerViewModel = headerViewModel

            snapshot.appendSections([headerViewModel])
            snapshot.appendItems(items)
        } else {
            headerViewModel = nil
        }

        dataSource.apply(snapshot, animatingDifferences: false)

        switch viewModel {
        case .start:
            emptyStateType = .start
        case .notFound:
            emptyStateType = .notFound
        case .found:
            emptyStateType = nil
        }

        applyState()
    }
}

// MARK: - Localizable

extension GovernanceDelegateSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
