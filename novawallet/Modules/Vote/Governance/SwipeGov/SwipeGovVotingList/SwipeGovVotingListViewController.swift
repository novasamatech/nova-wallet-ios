import UIKit
import SoraFoundation

final class SwipeGovVotingListViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwipeGovVotingListViewLayout

    let presenter: SwipeGovVotingListPresenterProtocol

    private var viewModel: SwipeGovVotingListViewModel?

    init(
        presenter: SwipeGovVotingListPresenterProtocol,
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
        view = SwipeGovVotingListViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTable()
        setupNavigationBar()
        setupVoteButton()

        applyLocalization()

        presenter.setup()
    }
}

// MARK: SwipeGovVotingListViewProtocol

extension SwipeGovVotingListViewController: SwipeGovVotingListViewProtocol {
    func didReceive(_ viewModel: SwipeGovVotingListViewModel) {
        self.viewModel = viewModel
        rootView.tableView.reloadData()
    }
    
    func didChangeViewModel(
        _ viewModel: SwipeGovVotingListViewModel,
        byRemovingItemWith referendumId: ReferendumIdLocal
    ) {
        guard let rowIndex = self.viewModel?.cellViewModels.firstIndex(where: {
            $0.referendumIndex == referendumId
        }) else {
            return
        }
        
        self.viewModel = viewModel
        
        let indexPath = IndexPath(row: rowIndex, section: 0)
        rootView.tableView.deleteRows(at: [indexPath], with: .left)
        
        if viewModel.cellViewModels.isEmpty {
            // TODO: Implement dismiss
        }

        updateVoteButton()
    }
}

// MARK: UITableViewDataSource

extension SwipeGovVotingListViewController: UITableViewDataSource {
    func tableView(
        _: UITableView,
        numberOfRowsInSection _: Int
    ) -> Int {
        viewModel?.cellViewModels.count ?? 0
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let viewModel = viewModel else {
            return UITableViewCell()
        }

        let cell = tableView.dequeueReusableCellWithType(SwipeGovVotingListItemCell.self)!

        let cellViewModel = viewModel.cellViewModels[indexPath.row]
        cell.bind(viewModel: cellViewModel)

        return cell
    }

    func tableView(
        _: UITableView,
        commit _: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        guard let cellModel = viewModel?.cellViewModels[indexPath.row] else {
            return
        }

        presenter.removeItem(with: cellModel.referendumIndex)
    }
}

// MARK: - UITableViewDelegate

extension SwipeGovVotingListViewController: UITableViewDelegate {
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let cellModel = viewModel?.cellViewModels[indexPath.row] else {
            return
        }

        presenter.selectVoting(for: cellModel.referendumIndex)
    }
}

// MARK: Localizable

extension SwipeGovVotingListViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            updateEditButton()
        }
    }
}

// MARK: Private

private extension SwipeGovVotingListViewController {
    func setupTable() {
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
        rootView.tableView.registerClassForCell(SwipeGovVotingListItemCell.self)
    }

    func setupNavigationBar() {
        let rightBarButtonItem = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(tapEditButton)
        )

        rightBarButtonItem.setupDefaultTitleStyle(with: .regularBody)

        navigationItem.rightBarButtonItem = rightBarButtonItem

        updateEditButton()
    }

    func setupVoteButton() {
        rootView.voteButton.addTarget(
            self,
            action: #selector(tapVoteButton),
            for: .touchUpInside
        )
        updateVoteButton()
    }

    func updateEditButton() {
        if rootView.tableView.isEditing {
            navigationItem.rightBarButtonItem?.title = R.string.localizable
                .commonDone(preferredLanguages: selectedLocale.rLanguages)
        } else {
            navigationItem.rightBarButtonItem?.title = R.string.localizable
                .commonEdit(preferredLanguages: selectedLocale.rLanguages)
        }
    }

    func updateVoteButton() {
        if !rootView.tableView.isEditing {
            rootView.voteButton.isUserInteractionEnabled = true
            rootView.voteButton.applyEnabledStyle()
        } else {
            rootView.voteButton.isUserInteractionEnabled = false
            rootView.voteButton.applyTranslucentDisabledStyle()
        }
    }
}

// MARK: Handlers

private extension SwipeGovVotingListViewController {
    @objc func tapEditButton() {
        rootView.tableView.setEditing(
            !rootView.tableView.isEditing,
            animated: true
        )
        updateEditButton()
        updateVoteButton()
    }

    @objc func tapVoteButton() {}
}
