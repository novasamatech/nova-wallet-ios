import UIKit
import SoraUI

final class DAppListItemsLoadingView: UICollectionViewCell {
    static let preferredHeight: CGFloat = 274.0

    let listBackgroundView = TriangularedBlurView()

    private var skeletonView: SkrullableView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(listBackgroundView)

        setupSkeleton()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        layoutAttributes.frame.size = CGSize(width: layoutAttributes.frame.width, height: Self.preferredHeight)
        return layoutAttributes
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        listBackgroundView.frame = CGRect(
            x: UIConstants.horizontalInset,
            y: 0.0,
            width: bounds.width - 2 * UIConstants.horizontalInset,
            height: bounds.height
        )

        setupSkeleton()
    }

    private func setupSkeleton() {
        let spaceSize = CGSize(width: listBackgroundView.frame.width, height: Self.preferredHeight)

        guard spaceSize.width > 0, spaceSize.height > 0 else {
            return
        }

        let builder = Skrull(size: spaceSize, decorations: [], skeletons: createSkeletons(for: spaceSize))

        let currentSkeletonView: SkrullableView?

        if let skeletonView = skeletonView {
            currentSkeletonView = skeletonView
            builder.updateSkeletons(in: skeletonView)
        } else {
            let view = builder
                .fillSkeletonStart(R.color.colorSkeletonStart()!)
                .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
                .build()
            view.autoresizingMask = []
            view.clipsToBounds = true
            listBackgroundView.addSubview(view)

            skeletonView = view

            view.startSkrulling()

            currentSkeletonView = view
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    private func createSkeletons(for size: CGSize) -> [Skeletonable] {
        createCellSkeletons(for: size)
    }

    private func createCellSkeletons(for size: CGSize) -> [Skeletonable] {
        let iconSize = CGSize(width: 48.0, height: 48.0)
        let titleSize = CGSize(width: 66.0, height: 12.0)
        let subtitleSize = CGSize(width: 120.0, height: 8.0)

        let offsetX = UIConstants.horizontalInset
        let offsetY = 16.0
        let spacing = 16.0

        let compoundSkeletons: [[Skeletonable]] = (0 ..< 4).map { index in
            let iconOffset = CGPoint(
                x: offsetX,
                y: offsetY + CGFloat(index) * (iconSize.height + spacing)
            )

            let iconSkeleton = SingleSkeleton.createRow(
                on: listBackgroundView,
                containerView: listBackgroundView,
                spaceSize: size,
                offset: iconOffset,
                size: iconSize
            )

            let titleOffset = CGPoint(
                x: iconOffset.x + iconSize.width + 12.0,
                y: iconOffset.y + 8.0
            )

            let titleSkeleton = SingleSkeleton.createRow(
                on: listBackgroundView,
                containerView: listBackgroundView,
                spaceSize: size,
                offset: titleOffset,
                size: titleSize
            )

            let subtitleOffset = CGPoint(
                x: iconOffset.x + iconSize.width + 12.0,
                y: titleOffset.y + titleSize.height + 10.0
            )

            let subtitleSkeleton = SingleSkeleton.createRow(
                on: listBackgroundView,
                containerView: listBackgroundView,
                spaceSize: size,
                offset: subtitleOffset,
                size: subtitleSize
            )

            return [iconSkeleton, titleSkeleton, subtitleSkeleton]
        }

        return compoundSkeletons.flatMap { $0 }
    }
}

extension DAppListItemsLoadingView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        setupSkeleton()
    }
}
