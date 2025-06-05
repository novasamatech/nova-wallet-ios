import UIKit
import Foundation_iOS

final class DelegatedAccountsUpdateViewController: UIViewController, ViewHolder {
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

        setup()
    }
}

// MARK: - Private

private extension DelegatedAccountsUpdateViewController {
    func setup() {
        setupTableView()
        setupDoneButton()
        setupSegmentedControl()
        setupInfoContent()
        setupLocalization()
        presenter.setup()
    }

    func setupInfoContent() {
        let text = R.string.localizable.delegateUpdatesHint(preferredLanguages: selectedLocale.rLanguages)
        let link = R.string.localizable.commonLearnMore(preferredLanguages: selectedLocale.rLanguages)

        rootView.infoView.bind(text: text, link: link)
        rootView.infoView.linkView.actionButton.addTarget(self, action: #selector(didTapOnInfoButton), for: .touchUpInside)
    }

    func createDataSource() -> DataSource {
        let dataSource = DataSource(tableView: rootView.tableView) { [weak self] tableView, indexPath, model in
            guard let self else { return UITableViewCell() }

            switch model {
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

    func setupTableView() {
        dataSource = createDataSource()
        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self
    }

    func setupDoneButton() {
        let preferredLanguages = selectedLocale.rLanguages
        rootView.doneButton.imageWithTitleView?.title = R.string.localizable.commonDone(
            preferredLanguages: preferredLanguages)
        rootView.doneButton.addTarget(self, action: #selector(didTapOnDoneButton), for: .touchUpInside)
    }

    func setupSegmentedControl() {
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

    func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable.delegateUpdatesTitle(
            preferredLanguages: selectedLocale.rLanguages)
        rootView.doneButton.imageWithTitleView?.title = R.string.localizable.commonDone(
            preferredLanguages: selectedLocale.rLanguages)

        let text = R.string.localizable.delegateUpdatesHint(preferredLanguages: selectedLocale.rLanguages)
        let link = R.string.localizable.commonLearnMore(preferredLanguages: selectedLocale.rLanguages)
        rootView.infoView.bind(text: text, link: link)
    }

    @objc func didTapOnDoneButton() {
        presenter.done()
    }

    @objc func didTapOnInfoButton() {
        presenter.showInfo()
    }

    @objc func segmentedControlValueChanged() {
        let selectedIndex = rootView.segmentedControl.selectedSegmentIndex
        let mode: DelegatedAccountsUpdateMode = selectedIndex == 0 ? .proxied : .multisig
        currentMode = mode
        presenter.didSelectMode(mode)
    }
}

// MARK: - DelegatedAccountsUpdateViewProtocol

extension DelegatedAccountsUpdateViewController: DelegatedAccountsUpdateViewProtocol {
    func didReceive(
        delegatedModels: [WalletView.ViewModel],
        revokedModels: [WalletView.ViewModel]
    ) {
        var snapshot = Snapshot()
        snapshot.appendSections([.delegated, .revoked])

        let delegatedRows = delegatedModels.map { Row.delegated($0) }
        let revokedRows = revokedModels.map { Row.revoked($0) }

        snapshot.appendItems(delegatedRows, toSection: .delegated)
        snapshot.appendItems(revokedRows, toSection: .revoked)

        dataSource?.apply(snapshot, animatingDifferences: false)
    }

    func preferredContentHeight(
        delegatedModelsCount: Int,
        revokedModelsCount: Int
    ) -> CGFloat {
        let titleTopOffset = DelegatedAccountsUpdateViewLayout.Constants.titleTopOffset
        let titleHeight: CGFloat = DelegatedAccountsUpdateViewLayout.Constants.titleHeight
        let titleToInfoSpacing = DelegatedAccountsUpdateViewLayout.Constants.titleToInfoSpacing
        let infoViewHeight: CGFloat = DelegatedAccountsUpdateViewLayout.Constants.infoHeight
        let infoToSegmentedSpacing = DelegatedAccountsUpdateViewLayout.Constants.infoToSegmentedSpacing
        let segmentControlHeight = DelegatedAccountsUpdateViewLayout.Constants.segmentedControlHeight
        let segmentToTableViewSpacing = DelegatedAccountsUpdateViewLayout.Constants.segmentToListSpacing
        let tableViewBottomOffset = DelegatedAccountsUpdateViewLayout.Constants.tableViewBottomOffset
        let doneButtonHeight = DelegatedAccountsUpdateViewLayout.Constants.doneButtonHeight
        let doneButtonBottomOffset = DelegatedAccountsUpdateViewLayout.Constants.doneButtonBottomOffset
        let tableCellHeight = Constants.tableCellHeight
        let sectionHeaderHeight = Constants.sectionHeaderHeight

        var sectionsWithHeaders = 0
        if delegatedModelsCount > 0 { sectionsWithHeaders += 1 }
        if revokedModelsCount > 0 { sectionsWithHeaders += 1 }

        let rowsCount = delegatedModelsCount + revokedModelsCount
        let tableViewHeight = CGFloat(rowsCount) * tableCellHeight + CGFloat(sectionsWithHeaders) * sectionHeaderHeight

        let totalHeight = titleTopOffset + titleHeight + titleToInfoSpacing + infoViewHeight +
            infoToSegmentedSpacing + segmentControlHeight + segmentToTableViewSpacing + tableViewHeight +
            tableViewBottomOffset + doneButtonHeight + doneButtonBottomOffset + 40

        return totalHeight
    }

    func switchMode(_ mode: DelegatedAccountsUpdateMode) {
        currentMode = mode
        rootView.segmentedControl.selectedSegmentIndex = mode == .proxied ? 0 : 1
    }
}

// MARK: - UITableViewDelegate

extension DelegatedAccountsUpdateViewController: UITableViewDelegate {
    func tableView(
        _: UITableView,
        heightForHeaderInSection section: Int
    ) -> CGFloat {
        switch Section.allCases[section] {
        case .delegated where dataSource?.snapshot().itemIdentifiers(inSection: .delegated).isEmpty == true:
            .zero
        case .revoked where dataSource?.snapshot().itemIdentifiers(inSection: .revoked).isEmpty == true:
            .zero
        default:
            Constants.sectionHeaderHeight
        }
    }

    func tableView(
        _ tableView: UITableView,
        viewForHeaderInSection section: Int
    ) -> UIView? {
        let sectionType = Section.allCases[section]

        let title: String = switch sectionType {
        case .delegated:
            R.string.localizable.delegateUpdatesWalletTypeMultisig(
                preferredLanguages: selectedLocale.rLanguages
            )
        case .revoked:
            R.string.localizable.delegateUpdatesRevoked(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        let headerView: SectionTextHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.bind(text: title)

        return headerView
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        rootView.updateStickyContent(with: scrollView.contentOffset.y)
    }

    func tableView(
        _: UITableView,
        heightForRowAt _: IndexPath
    ) -> CGFloat {
        Constants.tableCellHeight
    }
}

// MARK: - Localizable

extension DelegatedAccountsUpdateViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

// MARK: - Types

extension DelegatedAccountsUpdateViewController {
    typealias RootViewType = DelegatedAccountsUpdateViewLayout
    typealias DataSource = UITableViewDiffableDataSource<Section, Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Row>

    enum Section: CaseIterable {
        case delegated
        case revoked
    }

    enum Row: Hashable {
        case delegated(WalletView.ViewModel)
        case revoked(WalletView.ViewModel)
    }

    enum Constants {
        static let tableCellHeight: CGFloat = 48.0
        static let sectionHeaderHeight: CGFloat = 32.0
    }
}
