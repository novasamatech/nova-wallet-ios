import UIKit

final class KnownNetworksListViewLayout: UIView {
    let searchView = TopCustomSearchView()

    var searchTextField: UITextField {
        searchView.searchBar.textField
    }

    let tableView: UITableView = .create { view in
        view.backgroundColor = .clear
        view.separatorStyle = .none
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension KnownNetworksListViewLayout {
    func setupLayout() {
        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(52)
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
        }

        searchView.blurBackgroundView.removeFromSuperview()
        searchView.layoutIfNeeded()

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    func setupStyle() {
        searchView.searchBar.textFieldBackgroundView.cornerRadius = 10
        searchView.backgroundColor = R.color.colorSecondaryScreenBackground()
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }
}

// MARK: Model

extension KnownNetworksListViewLayout {
    enum Section: Hashable {
        case addNetwork([Row])
        case networks([Row])
    }

    enum Row: Hashable {
        case addNetwork(IconWithTitleViewModel)
        case network(NetworksListViewLayout.NetworkWithConnectionModel)
    }

    struct Model {
        let sections: [Section]
    }
}
