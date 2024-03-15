import UIKit
import SoraFoundation

final class ProxiedsUpdateViewController: UIViewController, ViewHolder {
    typealias RootViewType = ProxiedsUpdateViewLayout
    typealias DataSource = UITableViewDiffableDataSource<Section, Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Row>
    private var dataSource: DataSource?

    let presenter: ProxiedsUpdatePresenterProtocol

    init(
        presenter: ProxiedsUpdatePresenterProtocol,
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
        view = ProxiedsUpdateViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupDoneButton()
        setupLocalization()
        presenter.setup()
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(tableView: rootView.tableView) { [weak self] tableView, indexPath, model in
            guard let self = self else {
                return nil
            }

            switch model {
            case .info:
                let cell: ProxyInfoTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                let text = R.string.localizable.proxyUpdatesHint(preferredLanguages: self.selectedLocale.rLanguages)
                let link = R.string.localizable.proxyUpdatesHintLink(preferredLanguages: self.selectedLocale.rLanguages)
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

    private func setupLocalization() {
        rootView.titleLabel.text = R.string.localizable.proxyUpdatesTitle(
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
}

extension ProxiedsUpdateViewController: ProxiedsUpdateViewProtocol {
    func didReceive(
        delegatedModels: [WalletView.ViewModel],
        revokedModels: [WalletView.ViewModel]
    ) {
        let infoSection = Section.info
        let delegatedSection = Section.delegated
        let revokedSection = Section.revoked

        let delegatedViewModels = delegatedModels.map { Row.delegated($0) }
        let revokedViewModels = revokedModels.map { Row.revoked($0) }
        let infoViewModel = Row.info

        var snapshot = Snapshot()
        snapshot.appendSections([
            infoSection,
            delegatedSection,
            revokedSection
        ].compactMap { $0 })

        snapshot.appendItems([infoViewModel], toSection: infoSection)

        if !delegatedModels.isEmpty {
            snapshot.appendItems(delegatedViewModels, toSection: delegatedSection)
        }

        if !revokedModels.isEmpty {
            snapshot.appendItems(revokedViewModels, toSection: revokedSection)
        }

        dataSource?.apply(snapshot, animatingDifferences: [delegatedModels + revokedModels].count > 1)
    }

    func preferredContentHeight(
        delegatedModelsCount: Int,
        revokedModelsCount: Int
    ) -> CGFloat {
        let titleHeight: CGFloat = 58 + ProxiedsUpdateViewLayout.Constants.titleTopOffset
        let tableTopOffset: CGFloat = ProxiedsUpdateViewLayout.Constants.tableTopOffset
        let delegatedModelsHeaderHeight = delegatedModelsCount > 0 ? Constants.heightSectionHeader : 0
        let revokedModelsHeaderHeight = revokedModelsCount > 0 ? Constants.heightSectionHeader : 0
        let delegatedAccountsContentHeight = Constants.accountCellHeight * CGFloat(delegatedModelsCount)
        let revokedAccountsContentHeight = Constants.accountCellHeight * CGFloat(revokedModelsCount)
        let buttonHeight = UIConstants.actionHeight + UIConstants.actionBottomInset
        let text = R.string.localizable.proxyUpdatesHint(preferredLanguages: selectedLocale.rLanguages)
        let link = R.string.localizable.proxyUpdatesHintLink(preferredLanguages: selectedLocale.rLanguages)
        let headerHeight = ProxyInfoView.defaultHeight(
            text: text,
            link: link
        )
        return titleHeight + tableTopOffset + headerHeight + delegatedModelsHeaderHeight +
            delegatedAccountsContentHeight + revokedModelsHeaderHeight + revokedAccountsContentHeight + buttonHeight
    }
}

extension ProxiedsUpdateViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section) {
        case .info:
            return UITableView.automaticDimension
        case .delegated, .revoked:
            return Constants.accountCellHeight
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerSection = Section(rawValue: section) else {
            return nil
        }

        switch headerSection {
        case .info:
            return nil
        case .delegated:
            let numberOfRows = dataSource?.snapshot().numberOfItems(inSection: headerSection) ?? 0
            guard numberOfRows > 0 else {
                return nil
            }

            let title = R.string.localizable.commonProxieds(preferredLanguages: selectedLocale.rLanguages)
            let header: SectionTextHeaderFooterView = tableView.dequeueReusableHeaderFooterView()
            header.bind(text: title)
            return header
        case .revoked:
            let numberOfRows = dataSource?.snapshot().numberOfItems(inSection: headerSection) ?? 0
            guard numberOfRows > 0 else {
                return nil
            }

            let title = R.string.localizable.proxyUpdatesProxyRevoked(preferredLanguages: selectedLocale.rLanguages)
            let header: SectionTextHeaderFooterView = tableView.dequeueReusableHeaderFooterView()
            header.bind(text: title)
            return header
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let headerSection = Section(rawValue: section) else {
            return 0
        }

        switch headerSection {
        case .info:
            return 0
        case .delegated, .revoked:
            let numberOfRows = dataSource?.snapshot().numberOfItems(inSection: headerSection) ?? 0

            if numberOfRows > 0 {
                return Constants.heightSectionHeader
            } else {
                return 0
            }
        }
    }
}

extension ProxiedsUpdateViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

extension ProxiedsUpdateViewController {
    enum Section: Int, Hashable {
        case info
        case delegated
        case revoked
    }

    enum Row: Hashable {
        case info
        case delegated(WalletView.ViewModel)
        case revoked(WalletView.ViewModel)
    }
}

extension ProxiedsUpdateViewController {
    enum Constants {
        static let heightSectionHeader: CGFloat = 41
        static let accountCellHeight: CGFloat = 48
    }
}
