import UIKit
import SoraFoundation

final class TokensManageViewController: UIViewController, ViewHolder {
    typealias RootViewType = TokensManageViewLayout

    typealias DataSource = UITableViewDiffableDataSource<UITableView.Section, TokensManageViewModel>
    typealias Snapshot = NSDiffableDataSourceSnapshot<UITableView.Section, TokensManageViewModel>

    let presenter: TokensManagePresenterProtocol

    private lazy var dataSource = makeDataSource()

    init(presenter: TokensManagePresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = TokensManageViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTopBar()
        setupSearchField()
        setupTableView()
        setupLocalization()

        presenter.setup()
    }

    private func setupTopBar() {
        navigationItem.rightBarButtonItem = rootView.addTokenButton

        rootView.addTokenButton.target = self
        rootView.addTokenButton.action = #selector(actionAddToken)
    }

    private func setupSearchField() {
        rootView.searchTextField.addTarget(
            self,
            action: #selector(actionSearchEditingChanged),
            for: .editingChanged
        )
    }

    private func setupTableView() {
        rootView.tableView.rowHeight = 56
        rootView.tableView.registerClassForCell(TokensManageTableViewCell.self)
    }

    private func setupLocalization() {
        title = R.string.localizable.assetsManageTitle(preferredLanguages: selectedLocale.rLanguages)

        rootView.addTokenButton.title = R.string.localizable.commonAddToken(
            preferredLanguages: selectedLocale.rLanguages
        )

        let placeholder = R.string.localizable.tokensManageSearch(preferredLanguages: selectedLocale.rLanguages)
        rootView.searchTextField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorHintText()!
            ]
        )
    }

    private func getViewModel(for cell: TokensManageTableViewCell) -> TokensManageViewModel? {
        guard
            let indexPath = rootView.tableView.indexPath(for: cell),
            let viewModel = dataSource.itemIdentifier(for: indexPath) else {
            return nil
        }

        return viewModel
    }

    private func makeDataSource() -> DataSource {
        .init(tableView: rootView.tableView) { [weak self] tableView, _, viewModel in
            let cell = tableView.dequeueReusableCellWithType(TokensManageTableViewCell.self)
            cell?.delegate = self
            cell?.bind(viewModel: viewModel)
            return cell
        }
    }

    @objc private func actionAddToken() {
        presenter.performAddToken()
    }

    @objc private func actionSearchEditingChanged() {
        let query = rootView.searchTextField.text ?? ""

        presenter.search(query: query)
    }
}

extension TokensManageViewController: TokensManageTableViewCellDelegate {
    func tokensManageCellDidEdit(_ cell: TokensManageTableViewCell) {
        guard let viewModel = getViewModel(for: cell) else {
            return
        }

        presenter.performEdit(for: viewModel)
    }

    func tokensManageCellDidSwitch(_ cell: TokensManageTableViewCell, isOn: Bool) {
        guard let viewModel = getViewModel(for: cell) else {
            return
        }

        presenter.performSwitch(for: viewModel, isOn: isOn)
    }
}

extension TokensManageViewController: TokensManageViewProtocol {
    func didReceive(viewModels: [TokensManageViewModel]) {
        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels)

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension TokensManageViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
