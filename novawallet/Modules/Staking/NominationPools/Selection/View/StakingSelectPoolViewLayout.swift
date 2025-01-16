import UIKit
import UIKit_iOS

final class StakingSelectPoolViewLayout: UIView {
    let recommendedButton: RoundedButton = .create {
        $0.apply(style: .inactiveButton)
        $0.contentInsets = .init(top: 7, left: 12, bottom: 8, right: 12)
    }

    let tableView: UITableView = .create {
        $0.tableFooterView = UIView()
        $0.backgroundColor = .clear
        $0.separatorStyle = .none
        $0.registerClassForCell(StakingPoolTableViewCell.self)
        $0.registerHeaderFooterView(withClass: StakingSelectPoolListHeaderView.self)
    }

    let loadingView: ListLoadingView = .create {
        $0.isHidden = true
    }

    let searchButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(R.image.iconSearchWhite(), for: .normal)
        return button
    }()

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
        addSubview(recommendedButton)
        recommendedButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.top.equalTo(safeAreaLayoutGuide.snp.top).offset(12)
            $0.trailing.lessThanOrEqualToSuperview()
            $0.height.equalTo(32)
        }

        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(recommendedButton.snp.bottom).offset(16)
            $0.leading.bottom.trailing.equalToSuperview()
        }

        addSubview(loadingView)
        loadingView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}
