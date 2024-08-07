import UIKit

final class NetworksListViewLayout: UIView {
    let searchView = TopCustomSearchView()

    var searchTextField: UITextField {
        searchView.searchBar.textField
    }

    let networkTypeSwitch: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = R.color.colorSegmentedBackgroundOnBlack()!
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
    }

    let tableView: UITableView = .create { view in
        view.backgroundColor = .clear
        view.separatorStyle = .none
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.searchBarHeight)
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
        }

        searchView.blurBackgroundView.removeFromSuperview()
        searchView.layoutIfNeeded()

        addSubview(networkTypeSwitch)
        networkTypeSwitch.snp.makeConstraints { make in
            make.top.equalTo(searchView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(Constants.segmentControlHeight)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(networkTypeSwitch.snp.bottom).offset(8)
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

extension NetworksListViewLayout {
    struct NetworkWithConnectionModel: Hashable {
        enum OverallState {
            case enabled
            case disabled(String)
        }

        enum ConnectionState {
            case connecting(String)
            case connected
            case notConnected
        }

        var id: Int { networkModel.identifier }
        let index: Int
        let networkType: String?
        let connectionState: ConnectionState
        let networkState: OverallState
        let networkModel: DiffableNetworkViewModel

        static func == (
            lhs: NetworksListViewLayout.NetworkWithConnectionModel,
            rhs: NetworksListViewLayout.NetworkWithConnectionModel
        ) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    struct Placeholder: Hashable {
        let message: String
        let buttonTitle: String
    }

    enum Section: Hashable {
        case networks([Row])
        case banner([Row])
    }

    enum Row: Hashable {
        case network(NetworkWithConnectionModel)
        case banner
        case placeholder(Placeholder)
    }

    struct Model {
        let sections: [Section]
    }
}

// MARK: Constants

extension NetworksListViewLayout {
    enum Constants {
        static let segmentControlHeight: CGFloat = 40
        static let searchBarHeight: CGFloat = 52
    }
}
