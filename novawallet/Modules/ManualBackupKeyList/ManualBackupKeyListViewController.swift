import UIKit

final class ManualBackupKeyListViewController: UIViewController, ViewHolder {
    typealias RootViewType = ManualBackupKeyListViewLayout
    typealias ChainCell = ManualBackupChainTableViewCell
    typealias ViewModel = RootViewType.Model

    let presenter: ManualBackupKeyListPresenterProtocol

    private var viewModel: RootViewType.Model?

    init(presenter: ManualBackupKeyListPresenterProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ManualBackupKeyListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        presenter.setup()
    }
}

// MARK: UITableViewDataSource & UITableViewDelegate

extension ManualBackupKeyListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in _: UITableView) -> Int {
        viewModel?.accountsSections.count ?? 0
    }

    func tableView(
        _: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        switch viewModel?.accountsSections[section] {
        case let .customKeys(sectionModel):
            return sectionModel.accounts.count
        case let .defaultKeys(sectionModel):
            return sectionModel.accounts.count
        default:
            return 0
        }
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let viewModel else { return UITableViewCell() }

        let chainCell = tableView.dequeueReusableCellWithType(
            ChainCell.self,
            forIndexPath: indexPath
        )

        switch viewModel.accountsSections[indexPath.section] {
        case let .defaultKeys(viewModel):
            chainCell.networkIconView.image = R.image.iconNova()!
            chainCell.networkLabel.text = viewModel.accounts[indexPath.row].title
            chainCell.secondaryLabel.text = viewModel.accounts[indexPath.row].subtitle
            chainCell.secondaryLabel.isHidden = false
        case let .customKeys(viewModel):
            chainCell.bind(with: viewModel.accounts[indexPath.row].network)
        }

        chainCell.selectionStyle = .none

        return chainCell
    }

    func tableView(
        _: UITableView,
        heightForRowAt _: IndexPath
    ) -> CGFloat {
        Constants.cellHeight + ChainCell.Constants.bottomOffsetForSpacing
    }

    func tableView(
        _: UITableView,
        heightForHeaderInSection _: Int
    ) -> CGFloat {
        Constants.headerHeight
    }

    func tableView(
        _ tableView: UITableView,
        viewForHeaderInSection section: Int
    ) -> UIView? {
        let header: SettingsSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        let text = switch viewModel?.accountsSections[section] {
        case let .customKeys(sectionModel):
            sectionModel.headerText
        case let .defaultKeys(sectionModel):
            sectionModel.headerText
        default:
            String()
        }

        header.horizontalOffset = 0
        header.titleLabel.apply(style: .semiboldCaps2Secondary)
        header.titleLabel.text = text

        return header
    }

    func tableView(
        _: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        guard let viewModel else { return }

        switch viewModel.accountsSections[indexPath.section] {
        case .defaultKeys:
            presenter.didTapDefaultKey()
        case let .customKeys(model):
            let id = model.accounts[indexPath.row].chainId
            presenter.didTapCustomKey(with: id)
        }
    }
}

// MARK: ManualBackupKeyListViewProtocol

extension ManualBackupKeyListViewController: ManualBackupKeyListViewProtocol {
    func update(with viewModel: ManualBackupKeyListViewLayout.Model) {
        self.viewModel = viewModel

        rootView.headerView.bind(topValue: viewModel.listHeaderText, bottomValue: nil)
        rootView.updateHeaderLayout()
        rootView.tableView.reloadData()
    }

    func updateNavbar(with viewModel: DisplayWalletViewModel) {
        let iconDetailsView: IconDetailsView = .create(with: { view in
            view.detailsLabel.apply(style: .semiboldBodyPrimary)
            view.detailsLabel.text = viewModel.name
            view.iconWidth = Constants.walletIconSize.width

            viewModel.imageViewModel?.loadImage(
                on: view.imageView,
                targetSize: Constants.walletIconSize,
                animated: true
            )
        })

        navigationItem.titleView = iconDetailsView
    }
}

// MARK: Private

private extension ManualBackupKeyListViewController {
    func setup() {
        rootView.tableView.registerClassForCell(ChainCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: SettingsSectionHeaderView.self)

        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }
}

// MARK: Constants

private extension ManualBackupKeyListViewController {
    enum Constants {
        static let cellHeight: CGFloat = 64
        static let headerHeight: CGFloat = 53
        static let walletIconSize: CGSize = .init(
            width: 28,
            height: 28
        )
    }
}
