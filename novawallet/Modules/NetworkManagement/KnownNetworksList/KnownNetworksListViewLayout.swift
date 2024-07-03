import UIKit

final class KnownNetworksListViewLayout: UIView {

    let tableView: UITableView = .create { view in
        view.backgroundColor = .clear
        view.separatorStyle = .none
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()

        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}

// MARK: Model

extension KnownNetworksListViewLayout {
    struct AddNetworkRow: Hashable {
        var title: String
    }

    enum Section: Hashable {
        case addNetwork([Row])
        case networks([Row])
    }

    enum Row: Hashable {
        case addNetwork(AddNetworkRow)
        case network(NetworksListViewLayout.NetworkWithConnectionModel)
    }

    struct Model {
        let sections: [Section]
    }
}
