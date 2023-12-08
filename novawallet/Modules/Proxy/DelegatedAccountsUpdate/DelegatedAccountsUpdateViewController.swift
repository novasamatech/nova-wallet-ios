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
        presenter.setup()
    }

    private func createDataSource() -> DataSource {
        let dataSource = DataSource(tableView: rootView.tableView) { [weak self] tableView, indexPath, model in
            guard let self = self else {
                return nil
            }

            switch model {
            case .info:
                return UITableViewCell()
            case let .proxied(viewModel):
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
        rootView.doneButton.imageWithTitleView?.title = R.string.localizable.commonDone(
            preferredLanguages: selectedLocale.rLanguages)
        rootView.tableView.reloadData()
        title = "Delegated accounts update"
    }

    @objc private func didTapOnDoneButton() {
        presenter.done()
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

        let delegatedViewModels = delegatedModels.map { Row.proxied($0) }
        let revokedViewModels = revokedModels.map { Row.proxied($0) }
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
}

extension DelegatedAccountsUpdateViewController: UITableViewDelegate {
    func tableView(_: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section) {
        case .info:
            return 102
        case .delegated, .revoked:
            return 48
        default:
            return 0
        }
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch Section(rawValue: section) {
        case .info:
            return nil
        case .delegated:
            let header = UILabel()
            header.apply(style: .caption2Secondary)
            header.text = "DELEGATED TO YOU (PROXIEDS)"
            return header
        case .revoked:
            let header = UILabel()
            header.apply(style: .caption2Secondary)
            header.text = "Access was revoked".uppercased()
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
            return 25
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
        case proxied(ProxyWalletView.ViewModel)
    }
}
