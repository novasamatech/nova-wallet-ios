import UIKit

final class NetworksListViewLayout: UIView {
    let networkTypeSwitch: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = R.color.colorSegmentedBackgroundOnBlack()!
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
    }

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorStyle = .none
        return view
    }()

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
        addSubview(networkTypeSwitch)
        networkTypeSwitch.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(8)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(Constants.segmentControlHeight)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(networkTypeSwitch.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}

// MARK: Model

extension NetworksListViewLayout {
    struct NetworkWithConnectionModel: Hashable {
        var id: Int { networkModel.identifier }
        let connectionState: String?
        let enabled: Bool
        let networkModel: DiffableNetworkViewModel
    }

    struct Placeholder: Hashable {
        let message: String
        let buttonTitle: String
        let onTapButton: () -> Void

        static func == (
            lhs: Placeholder,
            rhs: Placeholder
        ) -> Bool {
            lhs.message == rhs.message &&
                lhs.buttonTitle == rhs.buttonTitle
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(message)
            hasher.combine(buttonTitle)
        }
    }

    struct Banner: Hashable {
        let title: String
        let message: String
        let buttonTitle: String
        let onTapClose: () -> Void

        static func == (
            lhs: Banner,
            rhs: Banner
        ) -> Bool {
            lhs.title == rhs.title &&
                lhs.message == rhs.message &&
                lhs.buttonTitle == rhs.buttonTitle
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
            hasher.combine(message)
            hasher.combine(buttonTitle)
        }
    }

    enum Section: Hashable {
        case networks([Row])
        case banner([Row])
    }

    enum Row: Hashable {
        case network(NetworkWithConnectionModel)
        case banner(Banner)
    }

    struct Model {
        let sections: [Section]
    }
}

// MARK: Constants

extension NetworksListViewLayout {
    enum Constants {
        static let segmentControlHeight: CGFloat = 40
    }
}
