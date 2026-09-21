import UIKit
import UIKit_iOS

final class SubtensorStakingStrategiesViewLayout: UIView {
    let collectionView: UICollectionView = {
        let layout = SubtensorStakingStrategiesCarouselLayout()

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.isPagingEnabled = false
        view.decelerationRate = .fast
        view.clipsToBounds = false
        return view
    }()

    let disclaimerLabel: UILabel = .create { label in
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .center
        label.numberOfLines = 3
    }

    let previousButton = SubtensorStakingStrategiesViewLayout.createArrowButton(isPrevious: true)
    let nextButton = SubtensorStakingStrategiesViewLayout.createArrowButton(isPrevious: false)
    let pageControl = ExtendedPageControl(spacing: Constants.pageControlSpacing)

    let activityIndicator: UIActivityIndicatorView = .create { view in
        view.color = R.color.colorIconSecondary()
        view.hidesWhenStopped = true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setLoading(_ isLoading: Bool) {
        collectionView.isHidden = isLoading
        disclaimerLabel.isHidden = isLoading
        previousButton.isHidden = isLoading
        nextButton.isHidden = isLoading
        pageControl.isHidden = isLoading

        if isLoading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    func updateSelection(index: Int, count: Int) {
        pageControl.currentPage = index

        previousButton.isEnabled = index > 0
        previousButton.alpha = index > 0 ? 1 : Constants.disabledButtonAlpha
        nextButton.isEnabled = index < count - 1
        nextButton.alpha = index < count - 1 ? 1 : Constants.disabledButtonAlpha
    }
}

private extension SubtensorStakingStrategiesViewLayout {
    static func createArrowButton(isPrevious: Bool) -> RoundedButton {
        let button = RoundedButton()
        button.applyIconWithBackgroundStyle()
        button.roundedBackgroundView?.cornerRadius = Constants.arrowButtonSize / 2
        button.contentInsets = .init(
            top: Constants.arrowIconInset,
            left: Constants.arrowIconInset,
            bottom: Constants.arrowIconInset,
            right: Constants.arrowIconInset
        )

        let image = R.image.iconChevronRight()?.tinted(with: R.color.colorIconPrimary()!)
        button.imageWithTitleView?.iconImage = isPrevious
            ? image?.withHorizontallyFlippedOrientation()
            : image

        return button
    }

    func setupLayout() {
        addSubview(collectionView)
        addSubview(disclaimerLabel)
        addSubview(previousButton)
        addSubview(nextButton)
        addSubview(pageControl)
        addSubview(activityIndicator)

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top).offset(Constants.collectionTopOffset)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.cardHeight)
        }

        disclaimerLabel.snp.makeConstraints { make in
            make.top.equalTo(collectionView.snp.bottom).offset(Constants.disclaimerTopOffset)
            make.leading.trailing.equalToSuperview().inset(Constants.disclaimerHorizontalInset)
        }

        previousButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(Constants.controlsBottomInset)
            make.size.equalTo(Constants.arrowButtonSize)
        }

        nextButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.bottom.equalTo(previousButton)
            make.size.equalTo(Constants.arrowButtonSize)
        }

        pageControl.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(previousButton)
            make.height.equalTo(Constants.pageControlHeight)
        }

        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}

final class SubtensorStakingStrategiesCarouselLayout: UICollectionViewFlowLayout {
    var selectedIndex = 0

    override init() {
        super.init()

        scrollDirection = .horizontal
        minimumLineSpacing = .zero
        minimumInteritemSpacing = .zero
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepare() {
        guard let collectionView, collectionView.bounds.width > 0 else {
            super.prepare()
            return
        }

        let availableWidth = max(
            collectionView.bounds.width - 2 * Constants.horizontalInset,
            1
        )
        let cardWidth = min(Constants.cardWidth, availableWidth)
        let horizontalInset = (collectionView.bounds.width - cardWidth) / 2

        itemSize = CGSize(width: cardWidth, height: Constants.cardHeight)
        sectionInset = UIEdgeInsets(
            top: 0,
            left: horizontalInset,
            bottom: 0,
            right: horizontalInset
        )

        super.prepare()
    }

    override func layoutAttributesForElements(
        in _: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
        guard
            collectionView != nil,
            let attributes = super.layoutAttributesForElements(
                in: CGRect(origin: .zero, size: collectionViewContentSize)
            )
        else {
            return nil
        }

        return attributes.compactMap { itemAttributes in
            guard let copiedAttributes = itemAttributes.copy() as? UICollectionViewLayoutAttributes else {
                return nil
            }

            let progress = inactiveProgress(forItemCenterX: copiedAttributes.center.x)
            let scale = 1 - Constants.scaleDifference * progress

            copiedAttributes.transform = CGAffineTransform(scaleX: scale, y: scale)
            copiedAttributes.zIndex = Int((1 - progress) * Constants.selectedZIndex)

            return copiedAttributes
        }
    }

    func inactiveProgress(forItemCenterX centerX: CGFloat) -> CGFloat {
        guard let collectionView else {
            return 1
        }

        let visibleCenterX = collectionView.bounds.midX
        let stride = max(itemSize.width + minimumLineSpacing, 1)

        return min(abs(centerX - visibleCenterX) / stride, 1)
    }

    override func shouldInvalidateLayout(forBoundsChange _: CGRect) -> Bool {
        true
    }

    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity _: CGPoint
    ) -> CGPoint {
        guard let collectionView else {
            return proposedContentOffset
        }

        let proposedCenterX = proposedContentOffset.x + collectionView.bounds.width / 2
        let targetRect = CGRect(
            x: proposedContentOffset.x,
            y: 0,
            width: collectionView.bounds.width,
            height: collectionView.bounds.height
        )

        guard let proposedAttributes = super.layoutAttributesForElements(in: targetRect)?.min(
            by: { abs($0.center.x - proposedCenterX) < abs($1.center.x - proposedCenterX) }
        ) else {
            return proposedContentOffset
        }

        let maximumIndex = max(collectionView.numberOfItems(inSection: 0) - 1, 0)
        let lowerBound = max(selectedIndex - 1, 0)
        let upperBound = min(selectedIndex + 1, maximumIndex)
        let targetIndex = min(
            max(proposedAttributes.indexPath.item, lowerBound),
            upperBound
        )

        guard let targetAttributes = super.layoutAttributesForItem(
            at: IndexPath(item: targetIndex, section: 0)
        ) else {
            return proposedContentOffset
        }

        let desiredOffsetX = targetAttributes.center.x - collectionView.bounds.width / 2
        let minimumOffsetX = -collectionView.adjustedContentInset.left
        let maximumOffsetX = max(
            minimumOffsetX,
            collectionViewContentSize.width
                - collectionView.bounds.width
                + collectionView.adjustedContentInset.right
        )

        return CGPoint(
            x: min(max(desiredOffsetX, minimumOffsetX), maximumOffsetX),
            y: proposedContentOffset.y
        )
    }
}

private extension SubtensorStakingStrategiesCarouselLayout {
    enum Constants {
        static let horizontalInset: CGFloat = 16
        static let cardWidth: CGFloat = 343
        static let cardHeight: CGFloat = 528
        static let scaleDifference: CGFloat = 0.06
        static let selectedZIndex: CGFloat = 1000
    }
}

extension SubtensorStakingStrategiesViewLayout {
    enum Constants {
        static let horizontalInset: CGFloat = 16
        static let collectionTopOffset: CGFloat = 18
        static let cardHeight: CGFloat = 528
        static let disclaimerTopOffset: CGFloat = 30
        static let disclaimerHorizontalInset: CGFloat = 32
        static let controlsBottomInset: CGFloat = 9
        static let arrowButtonSize: CGFloat = 36
        static let arrowIconInset: CGFloat = 8
        static let pageControlSpacing: CGFloat = 4
        static let pageControlHeight: CGFloat = 6
        static let disabledButtonAlpha: CGFloat = 0.4
    }
}
