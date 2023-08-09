import UIKit
import SoraUI

final class StakingTypeAccountView: RowView<
    GenericTitleValueView<IconDetailsGenericView<MultiValueView>, UIImageView>
> {
    var iconImageView: UIImageView { rowContentView.titleView.imageView }
    var titleLabel: UILabel { rowContentView.titleView.detailsView.valueTop }
    var subtitleLabel: UILabel { rowContentView.titleView.detailsView.valueBottom }
    var disclosureImageView: UIImageView { rowContentView.valueView }

    private var imageViewModel: ImageViewModelProtocol?

    var skeletonView: SkrullableView?

    private var isLoading: Bool = false

    var canProceed: Bool = true {
        didSet {
            updateActivityState()
        }
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

    private func configure() {
        roundedBackgroundView.apply(style: .roundedLightCell)
        preferredHeight = 52
        contentInsets = .init(top: 9, left: 16, bottom: 9, right: 12)
        borderView.borderType = .none

        titleLabel.textAlignment = .left
        subtitleLabel.textAlignment = .left
        titleLabel.apply(style: .footnotePrimary)
        subtitleLabel.apply(style: .init(
            textColor: R.color.colorTextPositive(),
            font: .caption1
        ))
    }

    private func updateActivityState() {
        if canProceed {
            disclosureImageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorTextSecondary()!)
        } else {
            disclosureImageView.image = nil
        }

        isUserInteractionEnabled = canProceed
    }

    func bind(viewModel: StakingTypeAccountViewModel) {
        imageViewModel?.cancel(on: iconImageView)
        imageViewModel = viewModel.imageViewModel
        iconImageView.image = nil

        let imageSize = rowContentView.titleView.iconWidth
        viewModel.imageViewModel?.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: imageSize, height: imageSize),
            animated: true
        )
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle

        if viewModel.isRecommended {
            subtitleLabel.apply(style: .init(
                textColor: R.color.colorTextPositive(),
                font: .caption1
            ))
        } else {
            subtitleLabel.apply(style: .caption1Secondary)
        }

        iconImageView.isHidden = viewModel.imageViewModel == nil
    }
}

extension StakingTypeAccountView: SkeletonableView {
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let titleSize = CGSize(width: 80, height: 10)
        let titleOffset = CGPoint(x: contentInsets.left, y: contentInsets.top + 4)

        let titleRow = SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: spaceSize,
            offset: titleOffset,
            size: titleSize
        )

        let detailsSize = CGSize(width: 101, height: 8)
        let detailsOffset = CGPoint(x: contentInsets.left, y: titleOffset.y + titleSize.height + 8)

        let detailsRow = SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: spaceSize,
            offset: detailsOffset,
            size: detailsSize
        )

        return [titleRow, detailsRow]
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
