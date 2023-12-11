import UIKit
import SoraFoundation

final class DelegatedAccountsUpdateViewController: UIViewController, ViewHolder {
    typealias RootViewType = DelegatedAccountsUpdateViewLayout
    typealias DataSource = UITableViewDiffableDataSource<Section, Row>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Row>
    private var dataSource: DataSource?

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
                let text = R.string.localizable.proxyUpdatesHint(preferredLanguages: selectedLocale.rLanguages)
                let link = R.string.localizable.proxyUpdatesHintLink(preferredLanguages: selectedLocale.rLanguages)
                cell.bind(text: text, link: link)
                cell.actionButton.addTarget(self, action: #selector(didTapOnInfoButton), for: .touchUpInside)
                return cell
            case let .delegated(viewModel), let .revoked(viewModel):
                let cell: ProxyTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.bind(viewModel: viewModel)
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

extension DelegatedAccountsUpdateViewController: DelegatedAccountsUpdateViewProtocol {
    func didReceive(
        delegatedModels: [ProxyWalletView.ViewModel],
        revokedModels: [ProxyWalletView.ViewModel]
    ) {
        let infoSection = Section.info
        let delegatedSection: Section? = !delegatedModels.isEmpty ? Section.delegated : nil
        let revokedSection: Section? = !revokedModels.isEmpty ? Section.revoked : nil

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
        if let delegatedSection = delegatedSection {
            snapshot.appendItems(delegatedViewModels, toSection: delegatedSection)
        }
        if let revokedSection = revokedSection {
            snapshot.appendItems(revokedViewModels, toSection: revokedSection)
        }
        dataSource?.apply(snapshot, animatingDifferences: [delegatedModels + revokedModels].count > 1)
    }

    func preferredContentHeight(
        delegatedModels: [ProxyWalletView.ViewModel],
        revokedModels: [ProxyWalletView.ViewModel]
    ) -> CGFloat {
        let delegatedModelsHeaderHeight = delegatedModels.isEmpty ? 0 : Constants.heightSectionHeader
        let revokedModelsHeaderHeight = revokedModels.isEmpty ? 0 : Constants.heightSectionHeader
        let delegatedAccountsContentHeight = Constants.accountCellHeight * CGFloat(delegatedModels.count)
        let revokedAccountsContentHeight = Constants.accountCellHeight * CGFloat(revokedModels.count)

        return delegatedModelsHeaderHeight + delegatedAccountsContentHeight +
            revokedModelsHeaderHeight + revokedAccountsContentHeight
    }
}

extension DelegatedAccountsUpdateViewController: UITableViewDelegate {
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
        switch Section(rawValue: section) {
        case .info:
            return nil
        case .delegated:
            let title = R.string.localizable.commonProxieds(preferredLanguages: selectedLocale.rLanguages)
            let header: SectionTextHeaderView = tableView.dequeueReusableHeaderFooterView()
            header.bind(text: title)
            return header
        case .revoked:
            let title = R.string.localizable.proxyUpdatesProxyRevoked(preferredLanguages: selectedLocale.rLanguages)
            let header: SectionTextHeaderView = tableView.dequeueReusableHeaderFooterView()
            header.bind(text: title)
            return header
        default:
            return nil
        }
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section) {
        case .info:
            return 0
        case .delegated, .revoked:
            return Constants.heightSectionHeader
        default:
            return 0
        }
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
    enum Section: Int, Hashable {
        case info
        case delegated
        case revoked
    }

    enum Row: Hashable {
        case info
        case delegated(ProxyWalletView.ViewModel)
        case revoked(ProxyWalletView.ViewModel)
    }
}

extension DelegatedAccountsUpdateViewController {
    enum Constants {
        static let heightSectionHeader: CGFloat = 41
        static let accountCellHeight: CGFloat = 48
    }
}
