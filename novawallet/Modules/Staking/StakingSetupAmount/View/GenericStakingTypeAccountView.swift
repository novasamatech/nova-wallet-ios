import UIKit
import UIKit_iOS

class GenericStakingTypeAccountView<T>: RowView<
    GenericTitleValueView<GenericPairValueView<T, MultiValueView>, UIImageView>
> where T: UIView {
    var titleLabel: UILabel { rowContentView.titleView.sView.valueTop }
    var subtitleLabel: UILabel { rowContentView.titleView.sView.valueBottom }
    var disclosureImageView: UIImageView { rowContentView.valueView }

    var genericViewSkeletonSize: CGSize = .zero

    var skeletonView: SkrullableView?
    var isLoading: Bool = false

    var canProceed: Bool = true {
        didSet {}
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
        updateActivityState()
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

    func configure() {
        roundedBackgroundView.apply(style: .roundedLightCell)
        preferredHeight = 52
        contentInsets = .init(top: 9, left: 16, bottom: 9, right: 14)
        borderView.borderType = .none

        titleLabel.textAlignment = .left
        subtitleLabel.textAlignment = .left
        titleLabel.apply(style: .footnotePrimary)
        subtitleLabel.apply(style: .init(
            textColor: R.color.colorTextPositive(),
            font: .caption1
        ))

        rowContentView.titleView.makeHorizontal()
        rowContentView.titleView.stackView.alignment = .center
        rowContentView.titleView.spacing = 12
        rowContentView.titleView.sView.spacing = 2
    }

    private func updateActivityState() {
        if canProceed {
            disclosureImageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorTextSecondary()!)
        } else {
            disclosureImageView.image = nil
        }

        isUserInteractionEnabled = canProceed
    }
}

extension GenericStakingTypeAccountView: SkeletonableView {
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        var skeletons: [Skeletonable] = []

        var leadingOffset: CGFloat = contentInsets.left

        if genericViewSkeletonSize != .zero {
            let offset = CGPoint(
                x: contentInsets.left,
                y: spaceSize.height / 2.0 - genericViewSkeletonSize.height / 2.0
            )

            let cornerRadius = 6 / genericViewSkeletonSize.height
            let cornerRadii = CGSize(width: cornerRadius, height: cornerRadius)

            let genericViewSkeleton = SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: offset,
                size: genericViewSkeletonSize,
                cornerRadii: cornerRadii
            )

            skeletons.append(genericViewSkeleton)

            leadingOffset = offset.x + genericViewSkeletonSize.width + rowContentView.titleView.spacing
        }

        let titleSize = CGSize(width: 80, height: 10)
        let titleOffset = CGPoint(x: leadingOffset, y: contentInsets.top + 4)

        let titleRow = SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: spaceSize,
            offset: titleOffset,
            size: titleSize
        )

        skeletons.append(titleRow)

        let detailsSize = CGSize(width: 101, height: 8)
        let detailsOffset = CGPoint(x: leadingOffset, y: titleOffset.y + titleSize.height + 8)

        let detailsRow = SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: spaceSize,
            offset: detailsOffset,
            size: detailsSize
        )

        skeletons.append(detailsRow)

        return skeletons
    }

    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [rowContentView]
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}
