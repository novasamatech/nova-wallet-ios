import UIKit
import SnapKit

final class ReferendumSearchViewLayout: BaseTableSearchViewLayout {
    override func setupLayout() {
        let backgroundView = UIImageView.background
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalTo(safeAreaLayoutGuide)
            make.top.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.bottom.equalToSuperview()
        }

        addSubview(searchView)
        searchView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(BaseTableSearchViewLayout.Constants.searchBarHeight)
        }

        let topOffset = BaseTableSearchViewLayout.Constants.searchBarHeight + 16
        tableView.contentInset = UIEdgeInsets(
            top: topOffset,
            left: 0,
            bottom: 16,
            right: 0
        )

        tableView.contentInsetAdjustmentBehavior = .always
        tableView.setContentOffset(.init(x: 0, y: -topOffset), animated: false)
    }

    override func setupStyle() {
        backgroundColor = .clear
        tableView.backgroundColor = .clear

        cancelButton.isHidden = false
        cancelButton.contentInsets = .init(top: 0, left: 16, bottom: 0, right: 16)
    }
}
