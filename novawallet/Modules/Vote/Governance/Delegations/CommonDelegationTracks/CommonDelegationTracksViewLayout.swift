import UIKit

final class CommonDelegationTracksViewLayout: UIView {
    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = .clear
        view.tableFooterView = UIView()
        view.separatorStyle = .none
        view.contentInset = .init(top: 0, left: 0, bottom: 16, right: 0)
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
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
    static func estimatePreferredHeight(for tracks: [TrackVote]) -> CGFloat {
        let titleHeight: CGFloat = 42
        var cellHeight: CGFloat = 44

        return titleHeight + cellHeight * CGFloat(tracks.count)
    }
}
