import UIKit
import UIKit_iOS

final class StakingTotalRewardView: UIView {
    let titleLabel: UILabel = .create { label in
        label.apply(style: .regularSubhedlineSecondary)
    }

    let filterView = BorderedActionControlView()

    let rewardView: MultiValueView = .create { view in
        view.valueTop.textColor = R.color.colorTextPrimary()
        view.valueTop.textAlignment = .left
        view.valueTop.font = .boldTitle3
        view.valueBottom.textColor = R.color.colorTextSecondary()
        view.valueBottom.textAlignment = .left
        view.valueBottom.font = .regularSubheadline
        view.spacing = 4.0
    }

    var skeletonView: SkrullableView?

    private var isLoading: Bool = false

    private var hasPrice: Bool = true

    override var intrinsicContentSize: CGSize {
        let height: CGFloat = hasPrice ? 80 : 60

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

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

    func bind(totalRewards: LoadableViewModelState<BalanceViewModelProtocol>, filter: String?, hasPrice: Bool) {
        stopLoadingIfNeeded()

        let title = totalRewards.value?.amount ?? ""
        let price = totalRewards.value?.price
        rewardView.bind(topValue: title, bottomValue: price)

        self.hasPrice = hasPrice

        if let filter = filter {
            filterView.isHidden = false
            filterView.bind(title: filter)
        } else {
            filterView.isHidden = true
        }

        if totalRewards.isLoading {
            startLoadingIfNeeded()
        }

        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview()
        }

        addSubview(filterView)
        filterView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8.0)
            make.trailing.lessThanOrEqualToSuperview()
            make.centerY.equalTo(titleLabel.snp.centerY)
        }

        addSubview(rewardView)
        rewardView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(titleLabel.snp.bottom).offset(8.0)
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
        let titleSkeleton = SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: spaceSize,
            offset: CGPoint(x: 0.0, y: 35.0),
            size: CGSize(width: 129, height: 16)
        )

        if hasPrice {
            let priceSkeleton = SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: 0.0, y: 65.0),
                size: CGSize(width: 56, height: 10)
            )

            return [titleSkeleton, priceSkeleton]
        } else {
            return [titleSkeleton]
        }
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}

extension StakingTotalRewardView: SkeletonLoadable {
    func didDisappearSkeleton() {
        if isLoading {
            skeletonView?.stopSkrulling()
        }
    }

    func didAppearSkeleton() {
        if isLoading {
            skeletonView?.restartSkrulling()
        }
    }

    func didUpdateSkeletonLayout() {
        if isLoading {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }
}
