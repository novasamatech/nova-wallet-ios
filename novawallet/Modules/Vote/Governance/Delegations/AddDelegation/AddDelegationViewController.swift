import UIKit
import Foundation_iOS
import UIKit_iOS

final class AddDelegationViewController: UIViewController, ViewHolder {
    typealias RootViewType = AddDelegationViewLayout

    let presenter: AddDelegationPresenterProtocol
    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, AddDelegationViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, AddDelegationViewModel>
    private lazy var dataSource = createDataSource()
    private var selectedFilter: GovernanceDelegatesFilter?
    private var selectedOrder: GovernanceDelegatesOrder?

    private lazy var bannerAnimator = BlockViewAnimator()

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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if dataSource.snapshot().numberOfItems == 0 {
            rootView.updateLoadingState()
        }
    }

    private func createDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { [weak self] tableView, indexPath, model -> UITableViewCell? in
            guard let self = self else {
                return nil
            }

            switch model {
            case let .yourDelegate(viewModel):
                let cell: GovernanceYourDelegationCell = tableView.dequeueReusableCell(for: indexPath)
                cell.bind(viewModel: viewModel, locale: self.selectedLocale)
                return cell
            case let .delegate(viewModel):
                let cell: GovernanceDelegateTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.bind(viewModel: viewModel, locale: self.selectedLocale)
                cell.applyStyle()
                return cell
            }
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
        rootView.bannerView.gradientBannerView.linkButton?.addTarget(
            self,
            action: #selector(didTapOnBannerLink),
            for: .touchUpInside
        )
        rootView.bannerView.closeButton.addTarget(
            self,
            action: #selector(didTapOnCloseBanner),
            for: .touchUpInside
        )

        navigationItem.rightBarButtonItem = rootView.searchButton
        rootView.searchButton.target = self
        rootView.searchButton.action = #selector(didTapSearch)
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

    @objc private func didTapSearch() {
        presenter.showSearch()
    }

    private func setupLocalization() {
        rootView.bannerView.set(locale: selectedLocale)
        selectedFilter.map {
            rootView.filterView.bind(
                title: GovernanceDelegatesFilter.title(for: selectedLocale),
                value: $0.value(for: selectedLocale)
            )
        }
        selectedOrder.map {
            rootView.sortView.bind(
                title: GovernanceDelegatesOrder.title(for: selectedLocale),
                value: $0.value(for: selectedLocale)
            )
        }
        rootView.tableView.reloadData()
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.delegationsAddTitle()
    }
}

extension AddDelegationViewController: AddDelegationViewProtocol {
    func didReceive(delegateViewModels: [AddDelegationViewModel]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(delegateViewModels)
        dataSource.apply(snapshot, animatingDifferences: false)

        if delegateViewModels.isEmpty {
            rootView.startLoadingIfNeeded()
        } else {
            rootView.stopLoadingIfNeeded()
        }
    }

    func didReceive(filter: GovernanceDelegatesFilter) {
        selectedFilter = filter

        rootView.filterView.bind(
            title: GovernanceDelegatesFilter.title(for: selectedLocale),
            value: filter.value(for: selectedLocale)
        )
    }

    func didReceive(order: GovernanceDelegatesOrder) {
        selectedOrder = order

        rootView.sortView.bind(
            title: GovernanceDelegatesOrder.title(for: selectedLocale),
            value: order.value(for: selectedLocale)
        )
    }

    func didChangeBannerState(isHidden: Bool, animated: Bool) {
        if animated {
            bannerAnimator.animate(
                block: {
                    self.rootView.setBanner(isHidden: isHidden)
                },
                completionBlock: nil
            )
        } else {
            rootView.setBanner(isHidden: isHidden)
        }
    }

    func didCompleteListConfiguration() {
        rootView.filterView.control.deactivate(animated: true)
        rootView.sortView.control.deactivate(animated: true)
    }
}

extension AddDelegationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let selectedItem = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        presenter.selectDelegate(address: selectedItem.address)
    }
}

extension AddDelegationViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
