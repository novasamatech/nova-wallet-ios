import UIKit
import UIKit_iOS

final class PayShopSkeletonBrandCell: BlurredCollectionViewCell<PayShopSkeletonBrandContentView> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
    }

    func startLoading() {
        view.view.startLoadingIfNeeded()
    }

    func stopLoading() {
        view.view.stopLoadingIfNeeded()
    }

    private func setupStyle() {
        view.contentInsets = .zero
        view.innerInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
    }
}

final class PayShopSkeletonBrandContentView: UIView {
    enum Constants {
        static let iconSize: CGFloat = 36
        static let iconDetailsSpacing: CGFloat = 12
        static let horizontalSpacing: CGFloat = 8
        static let cashbackSpacing: CGFloat = 0
        static let indicatorSpacing: CGFloat = 4
        static let indicatorWidth: CGFloat = 24
    }

    var skeletonView: SkrullableView?

    private var isLoading: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            updateLoadingState()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear
    }
}

extension PayShopSkeletonBrandContentView: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        []
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let imageSize = CGSize(width: Constants.iconSize, height: Constants.iconSize)
        let imageOffset = CGPoint(x: 0, y: (spaceSize.height - imageSize.height) / 2)

        let titleSize = CGSize(width: 73, height: 12)
        let titleOffset = CGPoint(
            x: imageOffset.x + imageSize.width + Constants.iconDetailsSpacing,
            y: spaceSize.height / 2 - titleSize.height / 2
        )

        let accessoryTopSize = CGSize(width: 57, height: 12)
        let accessoryBottomSize = CGSize(width: 49, height: 8)

        let accessoryTopOffset = CGPoint(
            x: spaceSize.width - accessoryTopSize.width,
            y: spaceSize.height / 2 - accessoryTopSize.height - 4
        )

        let accessoryBottomOffset = CGPoint(
            x: spaceSize.width - accessoryBottomSize.width,
            y: spaceSize.height / 2 + 4
        )

        return [
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: imageOffset,
                size: imageSize,
                cornerRadii: CGSize(width: imageSize.width / 2, height: imageSize.height / 2)
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: titleOffset,
                size: titleSize
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: accessoryTopOffset,
                size: accessoryTopSize
            ),
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: accessoryBottomOffset,
                size: accessoryBottomSize
            )
        ]
    }

    func didStartSkeleton() {
        isLoading = true
    }

    func didStopSkeleton() {
        isLoading = false
    }
}
