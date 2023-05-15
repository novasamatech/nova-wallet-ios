import UIKit
import SoraUI

class BaseTableSearchViewLayout: UIView {
    let searchView: CustomSearchView = {
        let view = CustomSearchView()
        view.searchBar.textField.autocorrectionType = .no
        view.searchBar.textField.autocapitalizationType = .none
        return view
    }()

    private var backgroundView: UIView?

    var searchField: UITextField { searchView.searchBar.textField }
    var cancelButton: RoundedButton { searchView.cancelButton }

    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView()
        tableView.rowHeight = UITableView.automaticDimension
        return tableView
    }()

    let emptyStateContainer = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        apply(style: .defaultStyle)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(54)
        }

        addSubview(emptyStateContainer)
        emptyStateContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalTo(safeAreaLayoutGuide)
            make.top.equalTo(searchView.snp.bottom)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom)
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.bottom.equalToSuperview()
        }
    }
}

extension BaseTableSearchViewLayout {
    struct Style {
        let background: Background
        let cancelButtonTitle: String?
        let contentInsets: UIEdgeInsets?
    }

    enum Background {
        case multigradient
        case colored(UIColor)
    }

    func apply(style: Style) {
        switch style.background {
        case .multigradient:
            guard backgroundView == nil else {
                return
            }
            let gradientView = MultigradientView.background
            insertSubview(gradientView, at: 0)
            gradientView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            backgroundView = gradientView
            backgroundColor = .clear
            tableView.backgroundColor = .clear
            emptyStateContainer.backgroundColor = .clear
        case let .colored(color):
            backgroundView?.removeFromSuperview()
            backgroundView = nil
            backgroundColor = color
            tableView.backgroundColor = color
            emptyStateContainer.backgroundColor = color
        }
        if let cancelButtonTitle = style.cancelButtonTitle {
            cancelButton.isHidden = false
            cancelButton.contentInsets = .init(top: 0, left: 16, bottom: 0, right: 16)
            cancelButton.imageWithTitleView?.title = cancelButtonTitle
        } else {
            cancelButton.isHidden = true
            cancelButton.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 16)
            searchView.invalidateIntrinsicContentSize()
        }
        style.contentInsets.map {
            tableView.contentInset = $0
        }
    }
}

extension BaseTableSearchViewLayout.Style {
    static let defaultStyle =
        BaseTableSearchViewLayout.Style(
            background: .colored(R.color.colorSecondaryScreenBackground()!),
            cancelButtonTitle: nil,
            contentInsets: nil
        )
}
