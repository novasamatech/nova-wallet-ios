import UIKit
import Foundation_iOS
import UIKit_iOS

final class CollatorStakingSelectSearchViewController: UIViewController, ViewHolder {
    typealias RootViewType = ValidatorSearchViewLayout

    let presenter: CollatorStakingSelectSearchPresenterProtocol

    private var viewModel: CollatorStakingSelectSearchViewModel?

    private lazy var searchActivityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.color = .white
        return activityIndicator
    }()

    init(
        presenter: CollatorStakingSelectSearchPresenterProtocol,
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
        view = ValidatorSearchViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupSearchView()
        setupLocalization()

        presenter.setup()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        rootView.searchField.resignFirstResponder()
    }

    private func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonSearch()

        rootView.searchField.placeholder = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.searchByAddressNamePlaceholder()
    }

    private func applyState() {
        rootView.tableView.isHidden = shouldDisplayEmptyState
        reloadEmptyState(animated: false)
    }

    private func setupTableView() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(CollatorSelectionCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: CustomValidatorListHeaderView.self)
        rootView.tableView.separatorStyle = .none
    }

    private func setupSearchView() {
        rootView.searchField.delegate = self
    }
}

extension CollatorStakingSelectSearchViewController: UITableViewDataSource {
    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.cellViewModels.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cellViewModels = viewModel?.cellViewModels else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCellWithType(CollatorSelectionCell.self)!
        cell.delegate = self

        let viewModel = cellViewModels[indexPath.row]
        cell.bind(viewModel: viewModel, type: .accentOnSorting)

        return cell
    }
}

extension CollatorStakingSelectSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        presenter.selectCollator(at: indexPath.row)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        guard viewModel?.headerViewModel != nil else { return 0 }
        return 26.0
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let headerViewModel = viewModel?.headerViewModel else { return nil }
        let headerView: CustomValidatorListHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.bind(viewModel: headerViewModel)
        return headerView
    }
}

extension CollatorStakingSelectSearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        guard let text = textField.text else { return false }

        presenter.search(text: text)
        return false
    }

    func textFieldShouldClear(_: UITextField) -> Bool {
        presenter.search(text: "")
        return true
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let text = textField.text as NSString? else {
            return true
        }

        let newString = text.replacingCharacters(in: range, with: string)
        presenter.search(text: newString)

        return true
    }
}

extension CollatorStakingSelectSearchViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate { self }
    var emptyStateDataSource: EmptyStateDataSource { self }
}

extension CollatorStakingSelectSearchViewController: EmptyStateDataSource {
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
        emptyView.titleFont = .regularFootnote
        return emptyView
    }

    var contentViewForEmptyState: UIView {
        rootView.contentView
    }

    var verticalSpacingForEmptyState: CGFloat? {
        26.0
    }
}

extension CollatorStakingSelectSearchViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        guard let viewModel = viewModel else { return true }
        return viewModel.cellViewModels.isEmpty
    }
}

extension CollatorStakingSelectSearchViewController: CollatorSelectionCellDelegate {
    func didTapInfoButton(in cell: CollatorSelectionCell) {
        if let indexPath = rootView.tableView.indexPath(for: cell) {
            presenter.presentCollatorInfo(at: indexPath.row)
        }
    }
}

extension CollatorStakingSelectSearchViewController: CollatorStakingSelectSearchViewProtocol {
    func didReceive(viewModel: CollatorStakingSelectSearchViewModel?) {
        self.viewModel = viewModel

        rootView.tableView.reloadData()
        applyState()
    }
}

extension CollatorStakingSelectSearchViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
