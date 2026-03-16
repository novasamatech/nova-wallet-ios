import UIKit
import UIKit_iOS

final class DAppSearchViewLayout: UIView {
    let searchBar = CustomSearchBar()

    let categoriesView = DAppCategoriesView()

    let topContainerView = UIView()

    let topBackgroundView: BlurBackgroundView = .create { view in
        view.sideLength = 0.0
        view.borderType = []
    }

    let stakingBannerView: StakingSearchBannerView = {
        let view = StakingSearchBannerView()
        view.isHidden = true
        return view
    }()

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.separatorStyle = .none
        return view
    }()

    let cancelBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem()
        item.tintColor = R.color.colorIconAccent()
        return item
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

    func setStakingBannerHidden(_ hidden: Bool) {
        stakingBannerView.isHidden = hidden

        tableView.snp.remakeConstraints { make in
            if hidden {
                make.top.equalTo(topBackgroundView.snp.bottom)
            } else {
                make.top.equalTo(stakingBannerView.snp.bottom)
            }
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupLayout() {
        addSubview(topBackgroundView)
        addSubview(categoriesView)
        addSubview(stakingBannerView)
        addSubview(tableView)

        categoriesView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).inset(Constants.categoriesViewVerticalInset)
            make.height.equalTo(DAppCategoriesView.preferredHeight)
            make.leading.trailing.equalToSuperview()
        }

        topBackgroundView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(categoriesView).inset(-Constants.categoriesViewVerticalInset)
        }

        stakingBannerView.snp.makeConstraints { make in
            make.top.equalTo(topBackgroundView.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(topBackgroundView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}

// Constants

private extension DAppSearchViewLayout {
    enum Constants {
        static let categoriesViewVerticalInset: CGFloat = 8.0
    }
}
