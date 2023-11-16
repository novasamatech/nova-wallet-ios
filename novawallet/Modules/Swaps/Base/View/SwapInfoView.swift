import UIKit
import SoraUI

final class SwapInfoView: GenericTitleValueView<RoundedButton, UILabel>, SkeletonableView {
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
        titleButton.imageWithTitleView?.iconImage = R.image.iconInfoFilled()
        titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        titleButton.imageWithTitleView?.titleFont = .regularFootnote
        titleButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 4
        titleButton.imageWithTitleView?.layoutType = .horizontalLabelFirst
        titleButton.contentInsets = .init(top: 8, left: 0, bottom: 8, right: 0)

        valueLabel.textColor = R.color.colorTextPrimary()
        valueLabel.font = .regularFootnote
    }
}

extension SwapInfoView {
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

extension SwapInfoView {
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
