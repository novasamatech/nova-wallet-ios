import UIKit

typealias SubtensorWhereToStakeCardCell = CollectionViewContainerCell<SubtensorWhereToStakeCardView>

final class SubtensorWhereToStakeViewLayout: UIView {
    let captionLabel = UILabel(style: .caption1Secondary, textAlignment: .center, numberOfLines: 0)
    let previousButton = SubtensorWhereToStakeViewLayout.makeArrowButton(flipped: true)
    let nextButton = SubtensorWhereToStakeViewLayout.makeArrowButton(flipped: false)
    let pageControl: ExtendedPageControl = .create { $0.currentPageIndicatorTintColor = R.color.colorIconAccent() }

    private(set) lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        view.backgroundColor = .clear
        view.alwaysBounceVertical = false
        view.contentInsetAdjustmentBehavior = .never
        view.registerCellClass(SubtensorWhereToStakeCardCell.self)
        return view
    }()

    private(set) var currentPage = 0

    private let horizontalDragLock = HorizontalDragLock()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
        horizontalDragLock.install(on: collectionView)
        previousButton.addAction(UIAction { [weak self] _ in self?.scroll(by: -1) }, for: .touchUpInside)
        nextButton.addAction(UIAction { [weak self] _ in self?.scroll(by: 1) }, for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(pageCount: Int, caption: String) {
        captionLabel.apply(text: caption, lineHeight: Constants.captionLineHeight)
        pageControl.numberOfPages = pageCount
        collectionView.reloadData()
        updatePage(min(currentPage, max(pageCount - 1, 0)))
    }
}

private extension SubtensorWhereToStakeViewLayout {
    static func makeArrowButton(flipped: Bool) -> UIButton {
        let image = UIGraphicsImageRenderer(size: Constants.arrowIconSize).image { _ in
            R.image.iconSmallArrow()?.draw(in: CGRect(origin: .zero, size: Constants.arrowIconSize))
        }.withRenderingMode(.alwaysTemplate)
        let button = UIButton(type: .custom)
        button.setImage(flipped ? image.withHorizontallyFlippedOrientation() : image, for: .normal)
        button.tintColor = R.color.colorIconSecondary()
        button.backgroundColor = R.color.colorChipsBackground()
        button.layer.cornerRadius = Constants.arrowSize / 2
        return button
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] _, environment in
            let insets = NSDirectionalEdgeInsets(
                top: 0,
                leading: Constants.horizontalInset,
                bottom: 0,
                trailing: Constants.cardSpacing + Constants.peekWidth
            )
            let width = environment.container.effectiveContentSize.width - insets.leading - insets.trailing
            let height = NSCollectionLayoutDimension.fractionalHeight(1)
            let item = NSCollectionLayoutItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: height)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(widthDimension: .absolute(width), heightDimension: height),
                subitems: [item]
            )
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .groupPaging
            section.interGroupSpacing = Constants.cardSpacing
            section.contentInsets = insets
            section.visibleItemsInvalidationHandler = { items, offset, _ in
                self?.updateFocus(items: items, offset: offset.x, stride: width + Constants.cardSpacing)
            }
            return section
        }
    }

    func scroll(by delta: Int) {
        let page = min(max(currentPage + delta, 0), pageControl.numberOfPages - 1)
        collectionView.scrollToItem(at: IndexPath(item: page, section: 0), at: .left, animated: true)
    }

    func updateFocus(items: [NSCollectionLayoutVisibleItem], offset: CGFloat, stride: CGFloat) {
        items.forEach { item in
            let distance = abs(item.frame.minX - Constants.horizontalInset - offset) / stride
            let focus = max(0, 1 - distance)
            item.alpha = Constants.peekAlpha + (1 - Constants.peekAlpha) * focus
            let cell = collectionView.cellForItem(at: item.indexPath) as? SubtensorWhereToStakeCardCell
            cell?.view.focus = focus
        }
        updatePage(Int((offset / stride).rounded()))
    }

    func updatePage(_ page: Int) {
        if pageControl.currentPage != page {
            pageControl.currentPage = page
        }
        currentPage = page
        [(previousButton, page > 0), (nextButton, page < pageControl.numberOfPages - 1)].forEach { button, enabled in
            button.isEnabled = enabled
            button.alpha = enabled ? 1 : Constants.disabledArrowAlpha
        }
    }

    func setupLayout() {
        [collectionView, captionLabel, previousButton, pageControl, nextButton].forEach(addSubview)
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(Constants.cardsTop)
            make.leading.trailing.equalToSuperview()
        }
        captionLabel.snp.makeConstraints { make in
            make.top.equalTo(collectionView.snp.bottom).offset(Constants.captionTop)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
        }
        previousButton.snp.makeConstraints { make in
            make.top.equalTo(captionLabel.snp.bottom).offset(Constants.arrowsTop)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.arrowsBottom)
            make.leading.equalToSuperview().inset(Constants.horizontalInset)
            make.size.equalTo(Constants.arrowSize)
        }
        nextButton.snp.makeConstraints { make in
            make.centerY.size.equalTo(previousButton)
            make.trailing.equalToSuperview().inset(Constants.horizontalInset)
        }
        pageControl.snp.makeConstraints { make in
            make.centerY.equalTo(previousButton)
            make.centerX.equalToSuperview()
        }
    }
}

private extension SubtensorWhereToStakeViewLayout {
    enum Constants {
        static let horizontalInset: CGFloat = 16
        static let cardSpacing: CGFloat = 12
        static let peekWidth: CGFloat = 44
        static let peekAlpha: CGFloat = 0.55
        static let cardsTop: CGFloat = 8
        static let captionTop: CGFloat = 16
        static let captionLineHeight: CGFloat = 16
        static let arrowsTop: CGFloat = 36
        static let arrowsBottom: CGFloat = 10
        static let arrowSize: CGFloat = 40
        static let arrowIconSize = CGSize(width: 20, height: 20)
        static let disabledArrowAlpha: CGFloat = 0.4
    }
}

private final class HorizontalDragLock: NSObject, UIGestureRecognizerDelegate {
    func install(on view: UIView) {
        let recognizer = UIPanGestureRecognizer()
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        view.addGestureRecognizer(recognizer)
    }

    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
        let translation = pan.translation(in: pan.view)
        return abs(translation.x) > abs(translation.y)
    }

    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizer(_: UIGestureRecognizer, shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        other.delegate is UIPresentationController
    }
}
