import UIKit

final class TokensManageViewLayout: UIView {
    let searchView = TokensManageSearchView()

    var searchBar: CustomSearchBar {
        searchView.searchBar
    }

    var filterSwitch: UISwitch {
        searchView.zeroBalanceFilterSwitch
    }

    var filterLabel: UILabel {
        searchView.zeroBalanceFilterLabel
    }

    var searchTextField: UITextField {
        searchBar.textField
    }

    let addTokenButton: UIBarButtonItem = {
        let button = UIBarButtonItem()
        button.style = .plain

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorButtonTextAccent()!,
            .font: UIFont.regularSubheadline
        ]

        button.setTitleTextAttributes(attributes, for: .normal)
        button.setTitleTextAttributes(attributes, for: .highlighted)

        return button
    }()

    let contentView: UIView = .create {
        $0.backgroundColor = .clear
    }

    let tableView: UITableView = .create {
        $0.backgroundColor = .clear
        $0.separatorStyle = .none
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(searchView)

        searchView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.preferredBarHeight)
        }

        contentView.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.contentInset = UIEdgeInsets(
            top: Constants.preferredBarHeight,
            left: 0,
            bottom: 0,
            right: 0
        )
    }
}

// MARK: Constants

private extension TokensManageViewLayout {
    enum Constants {
        static let preferredBarHeight: CGFloat = 98.0
    }
}
