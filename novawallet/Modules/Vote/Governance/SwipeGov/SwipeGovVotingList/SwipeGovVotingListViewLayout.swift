import UIKit

final class SwipeGovVotingListViewLayout: UIView {
    let tableView: UITableView = .create { view in
        view.backgroundColor = .clear
        view.separatorStyle = .none

        view.contentInset = UIEdgeInsets(
            top: 0.0,
            left: 0.0,
            bottom: 100.0,
            right: 0.0
        )
    }

    let voteButton: TriangularedButton = .create { view in
        view.applyDefaultStyle()
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
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.top.equalTo(safeAreaLayoutGuide)
            make.bottom.equalToSuperview()
        }

        addSubview(voteButton)
        voteButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }
    }
}
