import UIKit

final class BannersCollectionViewLayout: UICollectionViewFlowLayout {
    private let slideDistance: CGFloat
    private let verticalInset: CGFloat

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else {
            return nil
        }

        return attributes.map { self.transform($0) }
    }

    override func shouldInvalidateLayout(
        forBoundsChange _: CGRect
    ) -> Bool { true }

    init(
        slideDistance: CGFloat = 20.0,
        verticalInset: CGFloat = 0.0
    ) {
        self.slideDistance = slideDistance
        self.verticalInset = verticalInset

        super.init()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension BannersCollectionViewLayout {
    func transform(
        _ attributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        guard let collectionView else {
            return attributes
        }

        let distance = collectionView.frame.width
        let itemOffset = attributes.center.x - collectionView.contentOffset.x

        let position = itemOffset / distance - 0.5

        let contentOffset = collectionView.contentOffset
        let slideOffset = position * slideDistance

        let newOrigin = CGPoint(
            x: contentOffset.x,
            y: verticalInset
        )
        attributes.frame = CGRect(
            origin: newOrigin,
            size: attributes.frame.size
        )
        attributes.transform = CGAffineTransform(
            translationX: slideOffset,
            y: 0
        )

        attributes.alpha = 1 - abs(position * 1.4)

        return attributes
    }
}
