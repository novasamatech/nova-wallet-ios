import UIKit
import SoraUI

final class StakingTotalRewardView: UIView {
    let titleLabel: UILabel = .create { label in
        label.apply(style: .regularSubhedlineSecondary)
    }

    let filterView = BorderedActionControlView()

    let rewardView: MultiValueView = .create { view in
        view.valueTop.textColor = R.color.colorTextPrimary()
        view.valueTop.textAlignment = .left
        view.valueTop.font = .boldTitle2
        view.valueBottom.textColor = R.color.colorTextSecondary()
        view.valueBottom.textAlignment = .left
        view.valueBottom.font = .regularSubheadline
        view.spacing = 4.0
    }

    var skeletonView: SkrullableView?

    private var isLoading: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }

    func bind(totalRewards: LoadableViewModelState<BalanceViewModelProtocol>, filter: String?) {
        stopLoadingIfNeeded()

        let title = totalRewards.value?.amount ?? ""
        let price: String? = totalRewards.value?.price
        rewardView.bind(topValue: title, bottomValue: price)

        if let filter = filter {
            filterView.isHidden = false
            filterView.bind(title: filter)
        } else {
            filterView.isHidden = true
        }

        if totalRewards.isLoading {
            startLoadingIfNeeded()
        }
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview()
        }

        addSubview(filterView)
        filterView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8.0)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(titleLabel.snp.centerY)
        }

        addSubview(rewardView)
        rewardView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(titleLabel.snp.bottom).offset(4.0)
            make.bottom.equalToSuperview()
        }
    }
}

extension StakingTotalRewardView: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [rewardView.valueTop, rewardView.valueBottom, filterView]
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        [
            SingleSkeleton.createRow(
                under: titleLabel,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0.0, y: 12.0),
                size: UIConstants.skeletonBigRowSize
            ),
            SingleSkeleton.createRow(
                under: titleLabel,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0.0, y: 41.0),
                size: UIConstants.skeletonSmallRowSize
            )
        ]
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}
