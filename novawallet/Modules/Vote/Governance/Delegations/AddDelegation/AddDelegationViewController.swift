import UIKit
import SoraFoundation
import SoraUI

final class AddDelegationViewController: UIViewController, ViewHolder {
    typealias RootViewType = AddDelegationViewLayout

    let presenter: AddDelegationPresenterProtocol
    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, GovernanceDelegateTableViewCell.Model>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, GovernanceDelegateTableViewCell.Model>
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
        title = R.string.localizable.delegationsAddTitle(preferredLanguages: selectedLocale.rLanguages)
    }
}

extension AddDelegationViewController: AddDelegationViewProtocol {
    func didReceive(delegateViewModels: [GovernanceDelegateTableViewCell.Model]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(delegateViewModels)
        dataSource.apply(snapshot, animatingDifferences: false)
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
                    self.rootView.bannerView.isHidden = isHidden
                },
                completionBlock: nil
            )
        } else {
            rootView.bannerView.isHidden = isHidden
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

        presenter.selectDelegate(selectedItem)
    }
}

extension AddDelegationViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
