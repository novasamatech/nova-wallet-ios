import UIKit
import SoraFoundation

final class StakingDashboardViewController: UIViewController, ViewHolder {
    typealias RootViewType = StakingDashboardViewLayout

    let presenter: StakingDashboardPresenterProtocol
    let localizationManager: LocalizationManagerProtocol

    private var dashboardViewModel: StakingDashboardViewModel?
    private var walletViewModel: WalletSwitchViewModel?

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
            return dashboardViewModel?.active.count ?? 0
        case .inactiveStakings:
            return dashboardViewModel?.inactive.count ?? 0
        case .moreOptions:
            return dashboardViewModel?.hasMoreOptions == true ? 1 : 0
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

            let title = R.string.localizable.stakingTitle(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            )

            cell.bind(title: title)

            if let walletViewModel = walletViewModel {
                cell.bind(viewModel: walletViewModel)
            }

            return cell
        case .activeStakings:
            let cell: StakingDashboardActiveCell = collectionView.dequeueReusableCell(for: indexPath)!

            if let activeViewModel = dashboardViewModel?.active[indexPath.row] {
                cell.view.view.bind(
                    viewModel: activeViewModel,
                    locale: localizationManager.selectedLocale
                )
            }

            return cell
        case .inactiveStakings:
            let cell: StakingDashboardInactiveCell = collectionView.dequeueReusableCell(for: indexPath)!

            if let inactiveViewModel = dashboardViewModel?.inactive[indexPath.row] {
                cell.view.view.bind(
                    viewModel: inactiveViewModel,
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

            let title = R.string.localizable.multistakingInactiveHeader(
                preferredLanguages: localizationManager.selectedLocale.rLanguages
            )

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
            presenter.selectActiveStaking(at: indexPath.row)
        case .inactiveStakings:
            presenter.selectInactiveStaking(at: indexPath.row)
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
}

extension StakingDashboardViewController: StakingDashboardViewProtocol {
    func didReceiveWallet(viewModel: WalletSwitchViewModel) {
        walletViewModel = viewModel

        rootView.collectionView.reloadData()
    }

    func didReceiveStakings(viewModel: StakingDashboardViewModel) {
        dashboardViewModel = viewModel

        rootView.collectionView.reloadData()
    }
}

extension StakingDashboardViewController: HiddableBarWhenPushed {}
