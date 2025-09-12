import UIKit
import Foundation_iOS
import UIKit_iOS

final class ValidatorSearchViewController: BaseTableSearchViewController, ImportantViewProtocol {
    typealias RootViewType = ValidatorSearchViewLayout

    var presenter: ValidatorSearchPresenterProtocol? {
        basePresenter as? ValidatorSearchPresenterProtocol
    }

    private var viewModel: ValidatorSearchViewModel?

    private lazy var doneButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(tapDoneButton)
        )
        return button
    }()

    // MARK: - Lifecycle

    init(
        presenter: ValidatorSearchPresenterProtocol,
        localizationManager: LocalizationManager
    ) {
        super.init(basePresenter: presenter)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ValidatorSearchViewLayout()
    }

    override func viewDidLoad() {
        setupTable()
        setupNavigationBar()

        applyState()
        applyLocalization()

        super.viewDidLoad()
    }

    // MARK: - Private functions

    private func applyState() {
        rootView.tableView.isHidden = shouldDisplayEmptyState
        reloadEmptyState(animated: false)

        doneButton.isEnabled = viewModel?.differsFromInitial ?? false
    }

    private func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(CustomValidatorCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: CustomValidatorListHeaderView.self)
    }

    private func setupNavigationBar() {
        doneButton.setupDefaultTitleStyle(with: .regularBody)
        doneButton.isEnabled = false

        navigationItem.rightBarButtonItem = doneButton
    }

    private func presentValidatorInfo(at index: Int) {
        presenter?.didSelectValidator(at: index)
    }

    // MARK: - Actions

    @objc private func tapDoneButton() {
        presenter?.applyChanges()
    }
}

// MARK: - ValidatorSearchViewProtocol

extension ValidatorSearchViewController: ValidatorSearchViewProtocol {
    func didReload(_ viewModel: ValidatorSearchViewModel) {
        self.viewModel = viewModel
        rootView.tableView.reloadData()

        applyState()
    }

    func didReset() {
        viewModel = nil
        applyState()
    }
}

// MARK: - UITableViewDataSource

extension ValidatorSearchViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.cellViewModels.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellViewModels = viewModel?.cellViewModels else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCellWithType(CustomValidatorCell.self)!
        cell.delegate = self

        let viewModel = cellViewModels[indexPath.row]
        cell.bind(viewModel: viewModel)

        return cell
    }
}

// MARK: - UITableViewDelegate

extension ValidatorSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presenter?.changeValidatorSelection(at: indexPath.row)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        guard viewModel?.headerViewModel != nil else { return 0 }
        return 29
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let headerViewModel = viewModel?.headerViewModel else { return nil }
        let headerView: CustomValidatorListHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.bind(viewModel: headerViewModel)
        return headerView
    }
}

// MARK: - EmptyStateViewOwnerProtocol

extension ValidatorSearchViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

// MARK: - EmptyStateDataSource

extension ValidatorSearchViewController: EmptyStateDataSource {
    var viewForEmptyState: UIView? {
        let emptyView = EmptyStateView()

        if viewModel != nil {
            emptyView.image = R.image.iconEmptySearch()
            emptyView.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.stakingValidatorSearchEmptyTitle()
        } else {
            emptyView.image = R.image.iconStartSearch()
            emptyView.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonSearchStartTitle_v2_2_0()
        }

        emptyView.titleColor = R.color.colorTextSecondary()!
        emptyView.titleFont = .p2Paragraph
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.contentView
    }

    var verticalSpacingForEmptyState: CGFloat? {
        26.0
    }
}

// MARK: - EmptyStateDelegate

extension ValidatorSearchViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let viewModel = viewModel else { return true }
        return viewModel.cellViewModels.isEmpty
    }
}

// MARK: - CustomValidatorCellDelegate

extension ValidatorSearchViewController: CustomValidatorCellDelegate {
    func didTapInfoButton(in cell: CustomValidatorCell) {
        if let indexPath = rootView.tableView.indexPath(for: cell) {
            presentValidatorInfo(at: indexPath.row)
        }
    }
}

// MARK: - Localizable

extension ValidatorSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSearch()

            rootView.searchField.placeholder = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.searchByAddressNamePlaceholder()

            navigationItem.rightBarButtonItem?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonDone()
        }
    }
}
