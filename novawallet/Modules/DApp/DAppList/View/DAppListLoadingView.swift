import UIKit
import UIKit_iOS

private typealias SkeletonsWithBottomY = (skeletons: [Skeletonable], bottomY: CGFloat)

final class DAppListLoadingView: UICollectionViewCell {
    private var skeletonView: SkrullableView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupSkeleton()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        layoutAttributes.frame.size = CGSize(
            width: layoutAttributes.frame.width,
            height: UIScreen.main.bounds.height
        )
        return layoutAttributes
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        setupSkeleton()
    }
}

// MARK: Private

private extension DAppListLoadingView {
    func setupSkeleton() {
        let spaceSize = CGSize(
            width: bounds.width,
            height: UIScreen.main.bounds.height
        )

        guard spaceSize.width > 0, spaceSize.height > 0 else {
            return
        }

        let builder = Skrull(
            size: spaceSize,
            decorations: createDecorations(for: spaceSize),
            skeletons: createSkeletons(for: spaceSize)
        )

        let currentSkeletonView: SkrullableView?

        if let skeletonView {
            currentSkeletonView = skeletonView
            builder.updateSkeletons(in: skeletonView)
        } else {
            let view = builder
                .fillSkeletonStart(R.color.colorSkeletonStart()!)
                .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
                .build()
            view.autoresizingMask = []
            view.clipsToBounds = true

            addSubview(view)

            skeletonView = view

            view.startSkrulling()

            currentSkeletonView = view
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    func createSkeletons(for size: CGSize) -> [Skeletonable] {
        let categoriesSkeletons = createCategoriesSkeletons(for: size)

        let favoritesHeaderSkeletons = createSectionHeaderSkeletons(
            for: size,
            offsetY: categoriesSkeletons.bottomY + 28.0
        )
        let favoritesSkeletons = createFavoritesSkeletons(
            for: size,
            offsetY: favoritesHeaderSkeletons.bottomY + 16
        )

        let dappsSectionsSkeletons: [SkeletonsWithBottomY] = (0 ..< 3).reduce(into: []) { acc, _ in
            let offsetY = if let lastBottomY = acc.last?.bottomY {
                lastBottomY
            } else {
                favoritesSkeletons.bottomY
            }

            let categoryHeaderSkeletons = createSectionHeaderSkeletons(
                for: size,
                offsetY: offsetY + 28.0
            )
            let dAppsCellsSkeletons = createCellSkeletons(
                for: size,
                offsetY: categoryHeaderSkeletons.bottomY + 16
            )

            acc.append(categoryHeaderSkeletons)
            acc.append(dAppsCellsSkeletons)
        }

        let finalArray = [
            categoriesSkeletons,
            favoritesHeaderSkeletons,
            favoritesSkeletons
        ] + dappsSectionsSkeletons

        return finalArray.flatMap(\.skeletons)
    }

    func createCategoriesSkeletons(for size: CGSize) -> SkeletonsWithBottomY {
        let iconSize = CGSize(
            width: 20.0,
            height: 20.0
        )
        let textItemSize = CGSize(
            width: 32.0,
            height: 8.0
        )

        let offsetX: CGFloat = UIConstants.horizontalInset + 8.0
        let offsetY: CGFloat = 6.0

        let innerItemSpacing: CGFloat = 8.0
        let interItemSpacing: CGFloat = 8.0

        let totalItemSize = CGSize(
            width: 80.0,
            height: 32.0
        )

        let numberOfItems = Int(size.width / (totalItemSize.width + interItemSpacing)) + 1

        let skeletons = (0 ..< numberOfItems).flatMap { index in
            let iconOffset = CGPoint(
                x: CGFloat(index) * (totalItemSize.width + interItemSpacing) + offsetX,
                y: offsetY
            )
            let textOffset = CGPoint(
                x: iconOffset.x + innerItemSpacing + iconSize.width,
                y: offsetY + (iconSize.height - textItemSize.height) / 2
            )

            let iconSkeleton = SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: size,
                offset: iconOffset,
                size: iconSize,
                cornerRadii: CGSize(width: 10, height: 10)
            )
            let textSkeleton = SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: size,
                offset: textOffset,
                size: textItemSize
            )

            return [iconSkeleton, textSkeleton]
        }

        return (skeletons, totalItemSize.height)
    }

    func createDecorations(for size: CGSize) -> [SingleDecoration] {
        let itemSize = CGSize(width: 80.0, height: 32.0)

        let spacing: CGFloat = 8.0
        let offsetY: CGFloat = 0
        let offsetX: CGFloat = UIConstants.horizontalInset

        let numberOfItems = Int(size.width / (itemSize.width + spacing)) + 1

        return (0 ..< numberOfItems).map { index in
            let offset = CGPoint(
                x: CGFloat(index) * (itemSize.width + spacing) + offsetX,
                y: offsetY
            )

            let decoration = SingleDecoration.createDecoration(
                on: self,
                containerView: self,
                spaceSize: size,
                offset: offset,
                size: itemSize
            )
            .round(
                CGSize(
                    width: 10.0 / itemSize.width,
                    height: 10.0 / itemSize.height
                ),
                mode: .allCorners
            )
            .fill(R.color.colorButtonBackgroundSecondary()!)

            return decoration
        }
    }

    func createFavoritesSkeletons(
        for size: CGSize,
        offsetY: CGFloat
    ) -> SkeletonsWithBottomY {
        let iconSize = CGSize(
            width: 48.0,
            height: 48.0
        )
        let textItemSize = CGSize(
            width: 56.0,
            height: 8.0
        )

        let offsetX: CGFloat = 12.0

        let innerItemSpacing: CGFloat = 12.0
        let interItemSpacing: CGFloat = 24.0

        let totalItemSize = CGSize(
            width: textItemSize.width,
            height: iconSize.height + innerItemSpacing + textItemSize.height
        )

        let numberOfItems = Int(size.width / (totalItemSize.width + interItemSpacing)) + 1

        let skeletons = (0 ..< numberOfItems).flatMap { index in
            let textOffset = CGPoint(
                x: CGFloat(index) * (totalItemSize.width + interItemSpacing) + offsetX,
                y: offsetY + iconSize.height + innerItemSpacing
            )

            let iconOffset = CGPoint(
                x: textOffset.x + (textItemSize.width - iconSize.width) / 2,
                y: offsetY
            )

            let iconSkeleton = SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: size,
                offset: iconOffset,
                size: iconSize,
                cornerRadii: CGSize(
                    width: 12 / iconSize.width,
                    height: 12 / iconSize.height
                )
            )
            let textSkeleton = SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: size,
                offset: textOffset,
                size: textItemSize
            )

            return [iconSkeleton, textSkeleton]
        }

        return (skeletons, offsetY + totalItemSize.height)
    }

    func createSectionHeaderSkeletons(
        for size: CGSize,
        offsetY: CGFloat
    ) -> SkeletonsWithBottomY {
        let offsetX: CGFloat = UIConstants.horizontalInset

        let itemSize = CGSize(
            width: 88,
            height: 14
        )

        let offset = CGPoint(x: offsetX, y: offsetY)

        let skeleton = SingleSkeleton.createRow(
            on: self,
            containerView: self,
            spaceSize: size,
            offset: offset,
            size: itemSize
        )

        return ([skeleton], offsetY + itemSize.height)
    }

    func createCellSkeletons(
        for size: CGSize,
        offsetY: CGFloat
    ) -> SkeletonsWithBottomY {
        let iconSize = CGSize(width: 48.0, height: 48.0)
        let titleSize = CGSize(width: 96.0, height: 12.0)
        let subtitleSize = CGSize(width: 64.0, height: 8.0)

        let offsetX = UIConstants.horizontalInset
        let spacing = 16.0

        let totalHeight: CGFloat = (iconSize.height * 3) + (spacing * 2)

        let compoundSkeletons: [[Skeletonable]] = (0 ..< 3).map { index in
            let iconOffset = CGPoint(
                x: offsetX,
                y: offsetY + CGFloat(index) * (iconSize.height + spacing)
            )

            let iconSkeleton = SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: size,
                offset: iconOffset,
                size: iconSize,
                cornerRadii: CGSize(
                    width: 12 / iconSize.width,
                    height: 12 / iconSize.height
                )
            )

            let titleOffset = CGPoint(
                x: iconOffset.x + iconSize.width + 12.0,
                y: iconOffset.y + 8.0
            )

            let titleSkeleton = SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: size,
                offset: titleOffset,
                size: titleSize
            )

            let subtitleOffset = CGPoint(
                x: iconOffset.x + iconSize.width + 12.0,
                y: titleOffset.y + titleSize.height + 10.0
            )

            let subtitleSkeleton = SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: size,
                offset: subtitleOffset,
                size: subtitleSize
            )

            return [iconSkeleton, titleSkeleton, subtitleSkeleton]
        }

        return (compoundSkeletons.flatMap { $0 }, offsetY + totalHeight)
    }
}

// MARK: SkeletonLoadable

extension DAppListLoadingView: SkeletonLoadable {
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
