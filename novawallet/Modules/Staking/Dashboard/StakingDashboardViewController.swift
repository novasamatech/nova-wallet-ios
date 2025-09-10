import UIKit
import Foundation_iOS

final class StakingDashboardViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingDashboardViewLayout

    let presenter: StakingDashboardPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    private var dashboardViewModel: StakingDashboardViewModel?
    private var walletViewModel: WalletSwitchViewModel?

    private var isLoading: Bool { dashboardViewModel?.isLoading ?? false }

    private var activeItems: [StakingDashboardEnabledViewModel] { dashboardViewModel?.active ?? [] }
    private var inactiveItems: [StakingDashboardDisabledViewModel] { dashboardViewModel?.inactive ?? [] }
    private var hasMoreOptions: Bool { dashboardViewModel?.hasMoreOptions ?? false }

    init(
        presenter: StakingDashboardPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.localizationManager = localizationManager

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = StakingDashboardViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        updateLoadingState()
    }

    private func setupCollectionView() {
        rootView.collectionView.registerCellClass(WalletSwitchCollectionViewCell.self)

        rootView.collectionView.registerClass(
            TitleCollectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )

        rootView.collectionView.registerCellClass(StakingDashboardActiveCell.self)
        rootView.collectionView.registerCellClass(StakingDashboardInactiveCell.self)
        rootView.collectionView.registerCellClass(StakingDashboardMoreOptionsCell.self)

        rootView.collectionView.dataSource = self
        rootView.collectionView.delegate = self

        rootView.collectionView.refreshControl?.addTarget(
            self,
            action: #selector(actionRefresh),
            for: .valueChanged
        )
    }

    private func updateLoadingState() {
        rootView.collectionView.visibleCells.forEach { updateLoadingState(for: $0) }
    }

    private func updateLoadingState(for cell: UICollectionViewCell) {
        (cell as? AnimationUpdatibleView)?.updateLayerAnimationIfActive()
    }

    @objc private func actionRefresh() {
        presenter.refresh()
    }

    @objc private func actionSwitchWallet() {
        presenter.switchWallet()
    }
}

extension StakingDashboardViewController: UICollectionViewDataSource {
    func numberOfSections(in _: UICollectionView) -> Int {
        StakingDashboardSection.allCases.count
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let sectionModel = StakingDashboardSection(rawValue: section) else {
            return 0
        }

        switch sectionModel {
        case .walletSwitch:
            return 1
        case .activeStakings:
            return isLoading ? sectionModel.loadingCellsCount : activeItems.count
        case .inactiveStakings:
            return isLoading ? sectionModel.loadingCellsCount : inactiveItems.count
        case .moreOptions:
            return hasMoreOptions ? 1 : 0
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let section = StakingDashboardSection(rawValue: indexPath.section) else {
            return UICollectionViewCell()
        }

        switch section {
        case .walletSwitch:
            let cell: WalletSwitchCollectionViewCell = collectionView.dequeueReusableCell(for: indexPath)!

            cell.titleLabel.apply(style: .boldLargePrimary)

            cell.walletSwitch.addTarget(
                self,
                action: #selector(actionSwitchWallet),
                for: .touchUpInside
            )

            let title = R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.stakingTitle()

            cell.bind(title: title)

            if let walletViewModel = walletViewModel {
                cell.bind(viewModel: walletViewModel)
            }

            return cell
        case .activeStakings:
            let cell: StakingDashboardActiveCell = collectionView.dequeueReusableCell(for: indexPath)!

            if isLoading {
                cell.view.view.bindLoadingState()
            } else {
                cell.view.view.bind(
                    viewModel: activeItems[indexPath.row],
                    locale: localizationManager.selectedLocale
                )
            }

            return cell
        case .inactiveStakings:
            let cell: StakingDashboardInactiveCell = collectionView.dequeueReusableCell(for: indexPath)!

            if isLoading {
                cell.view.view.bindLoadingState()
            } else {
                cell.view.view.bind(
                    viewModel: inactiveItems[indexPath.row],
                    locale: localizationManager.selectedLocale
                )
            }

            return cell
        case .moreOptions:
            let cell: StakingDashboardMoreOptionsCell = collectionView.dequeueReusableCell(for: indexPath)!
            cell.bind(locale: localizationManager.selectedLocale)
            return cell
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let section = StakingDashboardSection(rawValue: indexPath.section)

        switch section {
        case .inactiveStakings:
            let header = collectionView.dequeueReusableSupplementaryViewWithType(
                TitleCollectionHeaderView.self,
                forSupplementaryViewOfKind: kind,
                for: indexPath
            )!

            let title = R.string(preferredLanguages: localizationManager.selectedLocale.rLanguages).localizable.multistakingInactiveHeader()

            header.bind(title: title)

            return header
        case .walletSwitch, .activeStakings, .moreOptions, .none:
            return UICollectionReusableView()
        }
    }
}

extension StakingDashboardViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let height = StakingDashboardSection(rawValue: indexPath.section)?.rowHeight ?? 0

        return CGSize(width: collectionView.frame.width, height: height)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout _: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        let height = StakingDashboardSection(rawValue: section)?.headerHeight ?? 0

        if height > 0 {
            return CGSize(width: collectionView.frame.width, height: height)
        } else {
            return .zero
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let sectionModel = StakingDashboardSection(rawValue: indexPath.section) else {
            return
        }

        switch sectionModel {
        case .activeStakings:
            if !isLoading {
                presenter.selectActiveStaking(at: indexPath.row)
            }
        case .inactiveStakings:
            if !isLoading {
                presenter.selectInactiveStaking(at: indexPath.row)
            }
        case .moreOptions:
            presenter.selectMoreOptions()
        case .walletSwitch:
            break
        }
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        StakingDashboardSection(rawValue: section)?.spacing ?? 0
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        StakingDashboardSection(rawValue: section)?.insets ?? .zero
    }

    func collectionView(
        _: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt _: IndexPath
    ) {
        updateLoadingState(for: cell)
    }
}

extension StakingDashboardViewController: StakingDashboardViewProtocol {
    func didReceiveWallet(viewModel: WalletSwitchViewModel) {
        walletViewModel = viewModel

        rootView.collectionView.reloadData()
    }

    func didReceiveStakings(viewModel: StakingDashboardViewModel) {
        dashboardViewModel = viewModel

        rootView.collectionView.reloadData()

        if !viewModel.isSyncing {
            rootView.collectionView.refreshControl?.endRefreshing()
        }
    }

    func didReceiveUpdate(viewModel: StakingDashboardUpdateViewModel) {
        dashboardViewModel = dashboardViewModel?.applyingUpdate(viewModel: viewModel)

        viewModel.active.forEach { item in
            let indexPath = IndexPath(item: item.0, section: StakingDashboardSection.activeStakings.rawValue)

            if let cell = rootView.collectionView.cellForItem(at: indexPath) as? StakingDashboardActiveCell {
                cell.view.view.bind(viewModel: item.1, locale: localizationManager.selectedLocale)
            }
        }

        viewModel.inactive.forEach { item in
            let indexPath = IndexPath(item: item.0, section: StakingDashboardSection.inactiveStakings.rawValue)

            if let cell = rootView.collectionView.cellForItem(at: indexPath) as? StakingDashboardInactiveCell {
                cell.view.view.bind(viewModel: item.1, locale: localizationManager.selectedLocale)
            }
        }

        if !viewModel.isSyncing {
            rootView.collectionView.refreshControl?.endRefreshing()
        }
    }
}

extension StakingDashboardViewController: HiddableBarWhenPushed {}
