import UIKit
import UIKit_iOS

class SwapGenericInfoView<V: UIView>: GenericTitleValueView<RoundedButton, V>, SkeletonableView {
    var titleButton: RoundedButton { titleView }
    var skeletonView: SkrullableView?

    private var isLoading: Bool = false

    var selectable: Bool = true {
        didSet {
            applySelectable()
        }
    }

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

    func configure() {
        titleButton.applyIconStyle()
        titleButton.imageWithTitleView?.titleColor = R.color.colorTextSecondary()
        titleButton.imageWithTitleView?.titleFont = .regularFootnote
        titleButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 4
        titleButton.imageWithTitleView?.layoutType = .horizontalLabelFirst
        titleButton.contentInsets = .init(top: 8, left: 0, bottom: 8, right: 0)

        applySelectable()
    }

    func applySelectable() {
        titleButton.imageWithTitleView?.iconImage = selectable ? R.image.iconInfoFilled() : nil
    }
}

extension SwapGenericInfoView {
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

final class SwapInfoView: SwapGenericInfoView<UILabel> {
    var valueLabel: UILabel { valueView }

    override func configure() {
        super.configure()

        valueLabel.textColor = R.color.colorTextPrimary()
        valueLabel.font = .regularFootnote
    }

    func bind(loadableViewModel: LoadableViewModelState<String>) {
        switch loadableViewModel {
        case let .cached(value), let .loaded(value):
            stopLoadingIfNeeded()
            valueView.text = value
        case .loading:
            startLoadingIfNeeded()
        }
    }
}
