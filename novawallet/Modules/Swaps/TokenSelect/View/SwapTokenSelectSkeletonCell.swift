import UIKit
import UIKit_iOS

final class SwapTokenSelectSkeletonCell: UITableViewCell {
    private var skeletonView: SkrullableView?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateSkeleton()
    }
}

// MARK: Private

private extension SwapTokenSelectSkeletonCell {
    func updateSkeleton() {
        let spaceSize = contentView.bounds.size

        guard spaceSize.width > 0, spaceSize.height > 0 else {
            return
        }

        let builder = Skrull(size: spaceSize, decorations: [], skeletons: createSkeletons(for: spaceSize))

        if let skeletonView {
            builder.updateSkeletons(in: skeletonView)
        } else {
            let view = builder
                .fillSkeletonStart(R.color.colorSkeletonStart()!)
                .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
                .build()
            view.autoresizingMask = []
            contentView.addSubview(view)

            skeletonView = view

            view.startSkrulling()
        }

        skeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let leadingBarsX = UIConstants.horizontalInset + Constants.iconSize + Constants.barsOffset
        let trailingTopBarX = spaceSize.width - UIConstants.horizontalInset - Constants.topBarSize.width
        let trailingBottomBarX = spaceSize.width - UIConstants.horizontalInset - Constants.bottomBarSize.width

        let frames: [CGRect] = [
            CGRect(
                origin: CGPoint(x: UIConstants.horizontalInset, y: Constants.iconTopInset),
                size: CGSize(width: Constants.iconSize, height: Constants.iconSize)
            ),
            CGRect(origin: CGPoint(x: leadingBarsX, y: Constants.topBarY), size: Constants.topBarSize),
            CGRect(origin: CGPoint(x: leadingBarsX, y: Constants.bottomBarY), size: Constants.bottomBarSize),
            CGRect(origin: CGPoint(x: trailingTopBarX, y: Constants.topBarY), size: Constants.topBarSize),
            CGRect(origin: CGPoint(x: trailingBottomBarX, y: Constants.bottomBarY), size: Constants.bottomBarSize)
        ]

        return frames.map { frame in
            SingleSkeleton.createRow(
                on: contentView,
                containerView: contentView,
                spaceSize: spaceSize,
                offset: frame.origin,
                size: frame.size
            )
        }
    }
}

// MARK: Constants

private extension SwapTokenSelectSkeletonCell {
    enum Constants {
        static let iconSize: CGFloat = 42
        static let iconTopInset: CGFloat = 8
        static let barsOffset: CGFloat = 10
        static let topBarSize = CGSize(width: 72, height: 14)
        static let bottomBarSize = CGSize(width: 48, height: 10)
        static let topBarY: CGFloat = 12
        static let bottomBarY: CGFloat = 34
    }
}
