import UIKit
import UIKit_iOS

final class VoteRowIndicatorView: RoundedView {
    var preferredSize = CGSize(width: 4.0, height: 16.0) {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        preferredSize
    }
}

final class VoteRowView: RowView<
    GenericTitleValueView<GenericPairValueView<VoteRowIndicatorView, UILabel>, IconDetailsView>
> {
    var titleLabel: UILabel { rowContentView.titleView.sView }

    var detailsLabel: UILabel { rowContentView.valueView.detailsLabel }

    var indicatorView: RoundedView { rowContentView.titleView.fView }

    var trailingImageView: UIImageView { rowContentView.valueView.imageView }

    var skeletonView: SkrullableView?

    private var isLoading: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        configureStyle()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureStyle() {
        preferredHeight = 44.0
        roundedBackgroundView.highlightedFillColor = R.color.colorCellBackgroundPressed()!
        borderView.borderType = .none

        rowContentView.titleView.setHorizontalAndSpacing(16.0)
        rowContentView.valueView.spacing = 8.0
        rowContentView.valueView.mode = .detailsIcon

        indicatorView.cornerRadius = 2.0
        indicatorView.shadowOpacity = 0.0

        rowContentView.valueView.iconWidth = 16.0

        titleLabel.apply(style: .rowTitle)
        detailsLabel.apply(style: .footnoteSecondary)
    }
}

extension VoteRowView: SkeletonableView {
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let size = CGSize(width: 68, height: 8)

        let xOffset = spaceSize.width
            - size.width
            - rowContentView.valueView.iconWidth
            - rowContentView.valueView.spacing
            - UIConstants.horizontalInset

        let yOffset = spaceSize.height / 2.0 - size.height / 2.0

        let offset = CGPoint(
            x: xOffset,
            y: yOffset
        )

        let row = SingleSkeleton.createRow(
            on: self,
            containerView: rowContentView.valueView,
            spaceSize: spaceSize,
            offset: offset,
            size: size
        )

        return [row]
    }

    var skeletonSuperview: UIView {
        rowContentView.valueView
    }

    var hidingViews: [UIView] {
        [detailsLabel]
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}

extension VoteRowView {
    struct Style {
        var color: UIColor
        var accessoryImage: UIImage
    }

    func apply(style: Style) {
        indicatorView.fillColor = style.color
        trailingImageView.image = style.accessoryImage

        setNeedsLayout()
    }
}

extension VoteRowView {
    struct Model {
        let title: String
        let votes: LoadableViewModelState<String>
    }

    func bind(viewModel: Model) {
        titleLabel.text = viewModel.title

        switch viewModel.votes {
        case let .cached(value), let .loaded(value):
            isLoading = false
            stopLoadingIfNeeded()
            detailsLabel.text = value
        case .loading:
            isLoading = true
            startLoadingIfNeeded()
        }
    }

    func bindOrHide(viewModel: Model?) {
        if let viewModel = viewModel {
            isHidden = false
            bind(viewModel: viewModel)
        } else {
            isHidden = true
        }
    }
}

extension UILabel.Style {
    static let rowTitle = UILabel.Style(
        textColor: R.color.colorTextPrimary(),
        font: .regularFootnote
    )
}
