import UIKit
import SoraFoundation

final class AddDelegationViewController: UIViewController, ViewHolder {
    typealias RootViewType = AddDelegationViewLayout

    let presenter: AddDelegationPresenterProtocol
    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, DelegateTableViewCell.Model>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, DelegateTableViewCell.Model>
    private lazy var dataSource = createDataSource()
    private var viewModel: [DelegateTableViewCell.Model] = []
    private var showValue: DelegatesShowOption?
    private var sortValue: DelegatesSortOption?

    init(presenter: AddDelegationPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = AddDelegationViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        rootView.tableView.dataSource = dataSource
        rootView.tableView.delegate = self

        setupHandlers()
        setupLocalization()
        presenter.setup()
    }

    private func createDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { [weak self] tableView, indexPath, _ -> UITableViewCell? in
            guard let self = self else {
                return nil
            }

            let cell: DelegateTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            let cellModel = self.viewModel[indexPath.row]
            cell.bind(viewModel: cellModel, locale: self.selectedLocale)
            cell.applyStyle()
            return cell
        }
    }

    private func setupHandlers() {
        rootView.filterView.control.addTarget(
            self,
            action: #selector(didTapOnFilter),
            for: .touchUpInside
        )
        rootView.sortView.control.addTarget(
            self,
            action: #selector(didTapOnSort),
            for: .touchUpInside
        )
        rootView.bannerView.bannerView.linkButton?.addTarget(
            self,
            action: #selector(didTapOnBannerLink),
            for: .touchUpInside
        )
        rootView.bannerView.closeButton.addTarget(
            self,
            action: #selector(didTapOnCloseBanner),
            for: .touchUpInside
        )
    }

    @objc private func didTapOnFilter() {
        presenter.showFilters()
    }

    @objc private func didTapOnSort() {
        presenter.showSortOptions()
    }

    @objc private func didTapOnBannerLink() {
        presenter.showAddDelegateInformation()
    }

    @objc private func didTapOnCloseBanner() {
        presenter.closeBanner()
    }

    private func setupLocalization() {
        rootView.bannerView.set(locale: selectedLocale)
        showValue.map {
            rootView.filterView.bind(
                title: $0.title(for: selectedLocale),
                value: $0.value(for: selectedLocale)
            )
        }
        sortValue.map {
            rootView.sortView.bind(
                title: $0.title(for: selectedLocale),
                value: $0.value(for: selectedLocale)
            )
        }
        rootView.tableView.reloadData()
    }
}

extension AddDelegationViewController: AddDelegationViewProtocol {
    func update(viewModel: [DelegateTableViewCell.Model]) {
        self.viewModel = viewModel

        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModel)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    func update(showValue: DelegatesShowOption) {
        self.showValue = showValue

        rootView.filterView.bind(
            title: showValue.title(for: selectedLocale),
            value: showValue.value(for: selectedLocale)
        )
    }

    func update(sortValue: DelegatesSortOption) {
        self.sortValue = sortValue
        rootView.sortView.bind(
            title: sortValue.title(for: selectedLocale),
            value: sortValue.value(for: selectedLocale)
        )
    }

    func showBanner() {
        rootView.bannerView.isHidden = false
        rootView.bannerView.set(locale: selectedLocale)
    }

    func hideBanner() {
        rootView.bannerView.isHidden = true
    }
}

extension AddDelegationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let cellModel = viewModel[indexPath.row]
        presenter.selectDelegate(cellModel)
    }
}

extension AddDelegationViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
