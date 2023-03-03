import UIKit
import SoraFoundation

final class GovernanceDelegateSearchViewController: BaseTableSearchViewController {
    var presenter: GovernanceDelegateSearchPresenterProtocol? {
        basePresenter as? GovernanceDelegateSearchPresenterProtocol
    }

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, GovernanceDelegateTableViewCell.Model>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, GovernanceDelegateTableViewCell.Model>
    private lazy var dataSource = createDataSource()

    init(presenter: GovernanceDelegateSearchPresenterProtocol, localizationManager _: LocalizationManagerProtocol) {
        super.init(basePresenter: presenter)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { [weak self] tableView, indexPath, model -> UITableViewCell? in
            guard let self = self else {
                return nil
            }

            let cell: GovernanceDelegateTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.bind(viewModel: model, locale: self.selectedLocale)
            cell.applyStyle()
            return cell
        }
    }
}

extension GovernanceDelegateSearchViewController: GovernanceDelegateSearchViewProtocol {
    func didReceive(viewModels: [GovernanceDelegateTableViewCell.Model]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - Localizable

extension GovernanceDelegateSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string.localizable.commonSearch(preferredLanguages: selectedLocale.rLanguages)

            rootView.searchField.placeholder = R.string.localizable.searchByAddressNamePlaceholder(
                preferredLanguages: selectedLocale.rLanguages
            )
        }
    }
}
