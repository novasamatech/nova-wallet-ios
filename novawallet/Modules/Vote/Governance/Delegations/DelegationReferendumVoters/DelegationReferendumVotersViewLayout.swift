import UIKit
import UIKit_iOS

final class DelegationReferendumVotersViewLayout: UIView, AdaptiveDesignable {
    var skeletonView: SkrullableView?

    let totalVotersLabel: BorderedLabelView = .create { view in
        view.backgroundView.fillColor = R.color.colorChipsBackground()!
        view.titleLabel.apply(style: .init(textColor: R.color.colorChipText()!, font: .semiBoldFootnote))
        view.contentInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        view.backgroundView.cornerRadius = 6
    }

    let settings = GenericCollectionViewLayoutSettings(
        pinToVisibleBounds: false,
        estimatedRowHeight: 44,
        absoluteHeaderHeight: 44,
        sectionContentInsets: .zero
    )

    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: compositionalLayout)
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.contentInset = settings.collectionViewContentInset
        return view
    }()

    private lazy var compositionalLayout = UICollectionViewCompositionalLayout(section: createCompositionalLayout())

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(collectionView)

        collectionView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func createCompositionalLayout() -> NSCollectionLayoutSection {
        .createSectionLayoutWithFullWidthRow(settings:
            .init(
                estimatedRowHeight: settings.estimatedRowHeight,
                absoluteHeaderHeight: settings.absoluteHeaderHeight,
                estimatedHeaderHeight: settings.estimatedSectionHeaderHeight,
                sectionContentInsets: settings.sectionContentInsets,
                sectionInterGroupSpacing: settings.interGroupSpacing,
                header: .init(pinToVisibleBounds: false)
            ))
    }
}

extension DelegationReferendumVotersViewLayout: SkeletonableView {
    var skeletonSpaceSize: CGSize {
        CGSize(width: frame.width, height: 44)
    }

    var skeletonReplica: SkeletonableViewReplica {
        let count = UInt32(20 * designScaleRatio.height)
        return SkeletonableViewReplica(count: count, spacing: 0.0)
    }

    var hidingViews: [UIView] { [] }

    var skeletonSuperview: UIView { self }

    // swiftlint:disable:next function_body_length
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let centerY = collectionView.contentInset.top + spaceSize.height / 2.0
        let insetX = UIConstants.horizontalInset

        let imageSize = CGSize(width: 22.0, height: 22.0)

        let nameSize = CGSize(width: 120.0, height: 14)
        let nameOffsetX = insetX + imageSize.width + VotesTableViewCell.Constants.addressNameSpacing

        let indicatorSize = CGSize(width: 12, height: 12)
        let indicatorOffsetX = nameOffsetX + nameSize.width +
            VotesTableViewCell.Constants.addressIndicatorSpacing

        let votesSize = CGSize(width: 60, height: 14)

        let votesDetailsSize = CGSize(width: 80, height: 14)

        return [
            SingleSkeleton.createRow(
                on: collectionView,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: insetX, y: centerY - imageSize.height / 2.0),
                size: imageSize
            ),
            SingleSkeleton.createRow(
                on: collectionView,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: nameOffsetX, y: centerY - nameSize.height / 2.0),
                size: nameSize
            ),
            SingleSkeleton.createRow(
                on: collectionView,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: indicatorOffsetX, y: centerY - indicatorSize.height / 2.0),
                size: indicatorSize
            ),
            SingleSkeleton.createRow(
                on: collectionView,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(
                    x: spaceSize.width - UIConstants.horizontalInset - votesSize.width,
                    y: collectionView.contentInset.top + spaceSize.height / 3 - votesSize.height / 2.0
                ),
                size: votesSize
            ),
            SingleSkeleton.createRow(
                on: collectionView,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(
                    x: spaceSize.width - UIConstants.horizontalInset - votesDetailsSize.width,
                    y: collectionView.contentInset.top + 2 * spaceSize.height / 3 - votesDetailsSize.height / 2.0
                ),
                size: votesDetailsSize
            )
        ]
    }
}
