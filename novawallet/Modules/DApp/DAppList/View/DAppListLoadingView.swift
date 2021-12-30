import UIKit
import SoraUI

final class DAppListLoadingView: UICollectionViewCell {
    static let preferredHeight: CGFloat = 266.0

    let listBackgroundView = TriangularedBlurView()
    let allView: RoundedButton = {
        let view = RoundedButton()
        view.imageWithTitleView?.titleFont = .regularFootnote
        view.roundedBackgroundView?.shadowOpacity = 0.0
        view.roundedBackgroundView?.strokeWidth = 0.0
        view.contentInsets = UIEdgeInsets(top: 9.0, left: 9.0, bottom: 9.0, right: 9.0)
        view.imageWithTitleView?.titleColor = R.color.colorWhite()!
        view.roundedBackgroundView?.fillColor = R.color.colorWhite16()!
        view.roundedBackgroundView?.highlightedFillColor = R.color.colorWhite16()!
        view.isUserInteractionEnabled = true
        return view
    }()

    private var skeletonView: SkrullableView?

    var selectedLocale = Locale.current {
        didSet {
            guard selectedLocale != oldValue else {
                return
            }

            setupLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(listBackgroundView)
        listBackgroundView.addSubview(allView)

        setupSkeleton()
        setupLocalization()
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

        let allViewSize = allView.intrinsicContentSize
        allView.frame = CGRect(x: 16.0, y: 16.0, width: allViewSize.width, height: allViewSize.height)

        setupSkeleton()
    }

    private func setupLocalization() {
        allView.imageWithTitleView?.title = R.string.localizable.commonAll(
            preferredLanguages: selectedLocale.rLanguages
        )
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
        createCategoriesSkeletons(for: size) + createCellSkeletons(for: size)
    }

    private func createCategoriesSkeletons(for size: CGSize) -> [Skeletonable] {
        let itemSize = CGSize(width: 48.0, height: 10.0)

        let spacing: CGFloat = 32.0
        let offsetX = allView.frame.maxX + 20.0
        let offsetY = 29.0

        let numberOfItems = Int((size.width - offsetX) / (itemSize.width + spacing)) + 1

        return (0 ..< numberOfItems).map { index in
            let offset = CGPoint(x: offsetX + CGFloat(index) * (itemSize.width + spacing), y: offsetY)

            return SingleSkeleton.createRow(
                on: listBackgroundView,
                containerView: listBackgroundView,
                spaceSize: size,
                offset: offset,
                size: itemSize
            )
        }
    }

    private func createCellSkeletons(for size: CGSize) -> [Skeletonable] {
        let iconSize = CGSize(width: 48.0, height: 48.0)
        let titleSize = CGSize(width: 66.0, height: 12.0)
        let subtitleSize = CGSize(width: 120.0, height: 8.0)

        let offsetX = UIConstants.horizontalInset
        let offsetY = 76.0
        let spacing = 16.0

        let compoundSkeletons: [[Skeletonable]] = (0 ..< 3).map { index in
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
