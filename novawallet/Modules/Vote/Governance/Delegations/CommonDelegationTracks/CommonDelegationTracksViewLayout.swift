import UIKit

final class CommonDelegationTracksViewLayout: UIView {
    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = .clear
        view.tableFooterView = UIView()
        view.separatorStyle = .none
        view.allowsSelection = false
        view.contentInset = .init(top: 0, left: 0, bottom: 16, right: 0)
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension CommonDelegationTracksViewLayout {
    static func estimatePreferredHeight(for tracks: [GovernanceTrackInfoLocal]) -> CGFloat {
        let titleHeight = Constants.titleHeight
        let cellHeight = Constants.cellHeight

        return titleHeight + cellHeight * CGFloat(tracks.count)
    }
}

extension CommonDelegationTracksViewLayout {
    enum Constants {
        static let cellHeight: CGFloat = 44
        static let titleHeight: CGFloat = 42
    }
}
