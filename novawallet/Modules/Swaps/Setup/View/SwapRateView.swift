import UIKit
import SoraUI

final class SwapRateView: GenericTitleValueView<RoundedButton, UILabel>, SkeletonableView {
    var titleButton: RoundedButton { titleView }
    var valueLabel: UILabel { valueView }
    var skeletonView: SkrullableView?

    private var isLoading: Bool = false

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        titleButton.applyIconStyle()
        titleButton.imageWithTitleView?.iconImage = R.image.iconInfoFilled()?.tinted(
            with: R.color.colorIconSecondary()!
        )
        titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        titleButton.imageWithTitleView?.titleFont = .regularFootnote
        titleButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 4
        titleButton.imageWithTitleView?.layoutType = .horizontalLabelFirst
        titleButton.contentInsets = .init(top: 8, left: 0, bottom: 8, right: 0)

        valueLabel.textColor = R.color.colorTextPrimary()
        valueLabel.font = .regularFootnote
    }
}

extension SwapRateView {
    func bind(loadableViewModel: LoadableViewModelState<String>) {
        switch loadableViewModel {
        case let .cached(value), let .loaded(value):
            stopLoadingIfNeeded()
            isLoading = false
            valueView.text = value
        case .loading:
            startLoadingIfNeeded()
            isLoading = true
        }
    }
}

extension SwapRateView {
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let size = CGSize(width: 68, height: 8)
        let offset = CGPoint(
            x: spaceSize.width - size.width,
            y: spaceSize.height / 2.0 - size.height / 2.0
        )

        let row = SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: spaceSize,
            offset: offset,
            size: size
        )

        return [row]
    }

    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [valueView]
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}

final class SwapRateViewCell: RowView<SwapRateView>, StackTableViewCellProtocol {
    var titleButton: RoundedButton { rowContentView.titleView }
    var valueLabel: UILabel { rowContentView.valueView }

    func bind(loadableViewModel: LoadableViewModelState<String>) {
        rowContentView.bind(loadableViewModel: loadableViewModel)
    }
}

final class SwapNetworkFeeViewCell: RowView<SwapNetworkFeeView>, StackTableViewCellProtocol {
    var titleButton: RoundedButton { rowContentView.titleView }
    var valueTopButton: RoundedButton { rowContentView.valueView.fView }
    var valueBottomLabel: UILabel { rowContentView.valueView.sView }

    func bind(loadableViewModel: LoadableViewModelState<SwapFeeViewModel>) {
        rowContentView.bind(loadableViewModel: loadableViewModel)
    }
}
