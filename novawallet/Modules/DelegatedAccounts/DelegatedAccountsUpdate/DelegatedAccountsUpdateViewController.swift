import UIKit
import Foundation_iOS

final class DelegatedAccountsUpdateViewController: UIViewController, ViewHolder {
    typealias RootViewType = DelegatedAccountsUpdateViewLayout
    typealias DataSource = UITableViewDiffableDataSource<Section, Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Row>
    private var dataSource: DataSource?
    private var currentMode: DelegatedAccountsUpdateMode = .proxied

    let presenter: DelegatedAccountsUpdatePresenterProtocol

    init(
        presenter: DelegatedAccountsUpdatePresenterProtocol,
        localizationManager: LocalizationManagerProtocol
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
        view = DelegatedAccountsUpdateViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupDoneButton()
        setupSegmentedControl()
        setupLocalization()
        presenter.setup()
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(tableView: rootView.tableView) { [weak self] tableView, indexPath, model in
            guard let self else { return UITableViewCell() }

            switch model {
            case .info:
                let cell: ProxyInfoTableViewCell = tableView.dequeueReusableCell(for: indexPath)

                let text = R.string.localizable.delegateUpdatesHint(preferredLanguages: self.selectedLocale.rLanguages)
                let link = R.string.localizable.commonLearnMore(preferredLanguages: self.selectedLocale.rLanguages)

                cell.bind(text: text, link: link)
                cell.actionButton.addTarget(self, action: #selector(self.didTapOnInfoButton), for: .touchUpInside)

                return cell

            case let .delegated(viewModel):
                let cell: ProxyTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.bind(viewModel: viewModel)
                ProxyUpdateStyle.delegated.apply(to: cell)
                return cell

            case let .revoked(viewModel):
                let cell: ProxyTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.bind(viewModel: viewModel)
                ProxyUpdateStyle.revoked.apply(to: cell)
                return cell
            }
        }

        dataSource.defaultRowAnimation = .fade
        return dataSource
    }

    private func setupTableView() {
        dataSource = createDataSource()
        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self
    }

    private func setupDoneButton() {
        let preferredLanguages = selectedLocale.rLanguages
        rootView.doneButton.imageWithTitleView?.title = R.string.localizable.commonDone(
            preferredLanguages: preferredLanguages)
        rootView.doneButton.addTarget(self, action: #selector(didTapOnDoneButton), for: .touchUpInside)
    }

    private func setupSegmentedControl() {
        rootView.segmentedControl.titles = [
            R.string.localizable.commonProxied(
                preferredLanguages: selectedLocale.rLanguages
            ),
            R.string.localizable.commonMultisig(
                preferredLanguages: selectedLocale.rLanguages
            )
        ]

        rootView.segmentedControl.addTarget(
            self,
            action: #selector(segmentedControlValueChanged),
            for: .valueChanged
        )
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable.delegateUpdatesTitle(
            preferredLanguages: selectedLocale.rLanguages)
        rootView.doneButton.imageWithTitleView?.title = R.string.localizable.commonDone(
            preferredLanguages: selectedLocale.rLanguages)
        rootView.tableView.reloadData()
    }

    @objc private func didTapOnDoneButton() {
        presenter.done()
    }

    @objc private func didTapOnInfoButton() {
        presenter.showInfo()
    }

    @objc private func segmentedControlValueChanged() {
        let selectedIndex = rootView.segmentedControl.selectedSegmentIndex
        let mode: DelegatedAccountsUpdateMode = selectedIndex == 0 ? .proxied : .multisig
        currentMode = mode
        presenter.didSelectMode(mode)
    }
}

extension DelegatedAccountsUpdateViewController: DelegatedAccountsUpdateViewProtocol {
    func didReceive(
        delegatedModels: [WalletView.ViewModel],
        revokedModels: [WalletView.ViewModel]
    ) {
        var snapshot = Snapshot()
        snapshot.appendSections([.delegated, .revoked, .info])

        let delegatedRows = delegatedModels.map { Row.delegated($0) }
        let revokedRows = revokedModels.map { Row.revoked($0) }

        snapshot.appendItems(delegatedRows, toSection: .delegated)
        snapshot.appendItems(revokedRows, toSection: .revoked)
        snapshot.appendItems([.info], toSection: .info)

        dataSource?.apply(snapshot, animatingDifferences: false)
    }

    func preferredContentHeight(
        delegatedModelsCount: Int,
        revokedModelsCount: Int
    ) -> CGFloat {
        let tableViewTop = rootView.tableView.frame.origin.y
        let doneButtonHeight = UIConstants.actionHeight
        let doneButtonInset = UIConstants.actionBottomInset
        let tableCellHeight = Constants.tableCellHeight

        let rowsCount = max(delegatedModelsCount + revokedModelsCount + 1, 1) // add info row
        let tableViewHeight = CGFloat(rowsCount) * tableCellHeight

        return tableViewTop + tableViewHeight + doneButtonHeight + doneButtonInset
    }

    func switchMode(_ mode: DelegatedAccountsUpdateMode) {
        currentMode = mode
        rootView.segmentedControl.selectedSegmentIndex = mode == .proxied ? 0 : 1
    }
}

extension DelegatedAccountsUpdateViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let sectionType = Section.allCases[section]
        switch sectionType {
        case .delegated where dataSource?.snapshot().itemIdentifiers(inSection: .delegated).isEmpty == true:
            return 0
        case .revoked where dataSource?.snapshot().itemIdentifiers(inSection: .revoked).isEmpty == true:
            return 0
        case .info:
            return 0
        default:
            return Constants.sectionHeaderHeight
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionType = Section.allCases[section]

        let title: String

        switch sectionType {
        case .delegated:
            title = R.string.localizable.delegateUpdatesWalletTypeMultisig(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .revoked:
            title = R.string.localizable.delegateUpdatesRevoked(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .info:
            return nil
        }

        let headerView: SectionTextHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.bind(text: title)

        return headerView
    }
}

extension DelegatedAccountsUpdateViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension DelegatedAccountsUpdateViewController {
    enum Section: CaseIterable {
        case delegated
        case revoked
        case info
    }

    enum Row: Hashable {
        case info
        case delegated(WalletView.ViewModel)
        case revoked(WalletView.ViewModel)
    }

    enum Constants {
        static let tableCellHeight: CGFloat = 48.0
        static let sectionHeaderHeight: CGFloat = 32.0
    }
}
