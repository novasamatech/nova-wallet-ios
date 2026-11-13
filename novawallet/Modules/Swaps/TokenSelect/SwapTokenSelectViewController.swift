import UIKit
import Foundation_iOS

final class SwapTokenSelectViewController: UIViewController, ViewHolder {
    typealias RootViewType = SwapTokenSelectViewLayout

    let presenter: SwapTokenSelectPresenterProtocol

    var keyboardHandler: KeyboardHandler?

    private var sections: [SwapTokenSelectSectionViewModel] = []
    private var listSignature: [String]?
    private var chipsSignature: [String]?

    init(presenter: SwapTokenSelectPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SwapTokenSelectViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        setupHandlers()
        setupLocalization()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardHandler()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }
}

// MARK: Private

private extension SwapTokenSelectViewController {
    func setupTableView() {
        rootView.tableView.registerClassForCell(SwapTokenSelectTokenCell.self)
        rootView.tableView.registerClassForCell(SwapTokenSelectSkeletonCell.self)
        rootView.tableView.registerHeaderFooterView(withClass: SwapTokenSelectSectionHeaderView.self)
        rootView.tableView.dataSource = self
        rootView.tableView.delegate = self
    }

    func setupHandlers() {
        rootView.closeButton.addTarget(self, action: #selector(actionClose), for: .touchUpInside)

        rootView.searchBar.textField.addTarget(
            self,
            action: #selector(actionSearchChanged),
            for: .editingChanged
        )

        rootView.searchBar.textField.delegate = self

        rootView.chipsView.onSelect = { [weak self] kind in
            self?.presenter.selectChip(kind)
            self?.scrollListToTop()
        }
    }

    func setupLocalization() {
        let placeholder = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.assetsSearchPlaceholder()

        rootView.searchBar.textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: R.color.colorButtonTextInactive()!,
                .font: UIFont.regularFootnote
            ]
        )
    }

    func apply(sections newSections: [SwapTokenSelectSectionViewModel]) {
        let newSignature = newSections.flatMap(\.signature)

        guard newSignature != listSignature else {
            sections = newSections
            return
        }

        sections = newSections
        listSignature = newSignature
        rootView.tableView.reloadData()
    }

    @objc func actionClose() {
        presenter.close()
    }

    func scrollListToTop() {
        let tableView = rootView.tableView
        tableView.setContentOffset(CGPoint(x: 0, y: -tableView.adjustedContentInset.top), animated: false)
    }

    @objc func actionSearchChanged() {
        presenter.search(query: rootView.searchBar.textField.text ?? "")
        scrollListToTop()
    }
}

// MARK: SwapTokenSelectViewProtocol

extension SwapTokenSelectViewController: SwapTokenSelectViewProtocol {
    func didReceive(title: String) {
        rootView.titleLabel.text = title
    }

    func didReceive(chips: [SwapTokenSelectChipViewModel]) {
        let newSignature = chips.map(\.signature)

        guard newSignature != chipsSignature else {
            return
        }

        chipsSignature = newSignature
        rootView.chipsView.bind(viewModels: chips)
    }

    func didReceive(list: SwapTokenSelectListViewModel) {
        switch list {
        case .loading:
            rootView.emptyView.isHidden = true
            apply(sections: [.loadingPlaceholder])
        case let .empty(text):
            rootView.emptyView.detailsLabel.text = text
            rootView.emptyView.isHidden = false
            apply(sections: [])
        case let .sections(sections):
            rootView.emptyView.isHidden = true
            apply(sections: sections)
        }
    }

    func didResetChipsScroll() {
        rootView.chipsView.scrollToStart()
    }
}

// MARK: UITableViewDataSource

extension SwapTokenSelectViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section].rows[indexPath.row] {
        case let .token(viewModel):
            let cell = tableView.dequeueReusableCellWithType(SwapTokenSelectTokenCell.self, forIndexPath: indexPath)
            cell.bind(viewModel: viewModel)
            return cell
        case .loading:
            return tableView.dequeueReusableCellWithType(SwapTokenSelectSkeletonCell.self, forIndexPath: indexPath)
        }
    }
}

// MARK: UITableViewDelegate

extension SwapTokenSelectViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = sections[section].title

        guard !title.isEmpty else {
            return nil
        }

        let headerView: SwapTokenSelectSectionHeaderView = tableView.dequeueReusableHeaderFooterView()
        headerView.titleLabel.text = title
        return headerView
    }

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        sections[section].title.isEmpty ? 0 : SwapTokenSelectSectionHeaderView.Constants.height
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard case let .token(viewModel) = sections[indexPath.section].rows[indexPath.row] else {
            return
        }

        presenter.selectToken(with: viewModel.chainAssetId)
    }
}

// MARK: UITextFieldDelegate

extension SwapTokenSelectViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: KeyboardAdoptable

extension SwapTokenSelectViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let tableView = rootView.tableView
        let keyboardFrame = rootView.convert(frame, from: nil)
        let overlap = max(rootView.bounds.maxY - keyboardFrame.minY - rootView.safeAreaInsets.bottom, 0)

        tableView.contentInset.bottom = overlap
        tableView.verticalScrollIndicatorInsets.bottom = overlap
    }
}

// MARK: Localizable

extension SwapTokenSelectViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}

// MARK: Signatures

private extension SwapTokenSelectSectionViewModel {
    static var loadingPlaceholder: SwapTokenSelectSectionViewModel {
        SwapTokenSelectSectionViewModel(
            title: "",
            rows: Array(repeating: .loading, count: SwapTokenSelectViewController.Constants.loadingRowsCount)
        )
    }

    var signature: [String] {
        [title] + rows.map { row in
            switch row {
            case let .token(viewModel):
                [
                    viewModel.chainAssetId.stringValue,
                    viewModel.balance?.amount ?? "",
                    viewModel.balance?.price ?? "",
                    String(viewModel.isCurrent)
                ].joined(with: .slash)
            case .loading:
                "loading"
            }
        }
    }
}

private extension SwapTokenSelectChipViewModel {
    var signature: String {
        [String(describing: kind), title, String(isSelected)].joined(with: .slash)
    }
}

private extension SwapTokenSelectViewController {
    enum Constants {
        static let loadingRowsCount = 6
    }
}
