import UIKit
import UIKit_iOS
import SnapKit

final class BannersViewLayout: UIView {
    var loadingState: LoadingState = .none {
        didSet {
            if loadingState == .none {
                stopLoadingIfNeeded()
            } else {
                startLoadingIfNeeded()
            }
        }
    }

    var skeletonView: SkrullableView?

    let backgroundView: BannerBackgroundView = .create { view in
        view.clipsToBounds = true
        view.layer.cornerRadius = Constants.backgroundCornerRaius
        view.layer.borderWidth = Constants.borderWidth
        view.layer.borderColor = R.color.colorContainerBorder()?.cgColor
    }

    let closeButton: RoundedButton = .create { button in
        button.applyIconStyle()
        button.imageWithTitleView?.iconImage = R.image.iconBannerClose()!
    }

    lazy var pageControl = ExtendedPageControl()

    lazy var collectionView: UICollectionView = {
        let layout = BannersCollectionViewLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.isPagingEnabled = true

        return collectionView
    }()

    var availableTextWidth: CGFloat {
        bounds.width
            - Constants.contentLeadingOffset
            - BannerView.Constants.contentImageViewWidth
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        restartLoadingIfNeeded()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension BannersViewLayout {
    func setupLayout() {
        addSubview(backgroundView)
        addSubview(collectionView)
        addSubview(pageControl)
        addSubview(closeButton)

        backgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalTo(collectionView).inset(Constants.containerVerticalInset)
            make.height.equalTo(Constants.containerViewMinHeight)
        }
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(pageControl.snp.top)
        }
        pageControl.snp.makeConstraints { make in
            make.bottom.centerX.equalToSuperview()
            make.height.equalTo(Constants.pageControlHeight)
        }
        closeButton.snp.makeConstraints { make in
            make.size.equalTo(CGSize(width: 32, height: 28))
            make.trailing.equalToSuperview()
            make.top.equalToSuperview().inset(Constants.containerVerticalInset)
        }
    }
}

// MARK: SkeletonableView

extension BannersViewLayout: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [
            backgroundView,
            collectionView,
            pageControl,
            closeButton
        ]
    }

    func createDecorations(for spaceSize: CGSize) -> [any Decorable] {
        let cornerRadii = CGSize(
            width: Constants.backgroundCornerRaius / spaceSize.width,
            height: Constants.backgroundCornerRaius / spaceSize.height
        )
        let offset = CGPoint(
            x: .zero,
            y: Constants.containerVerticalInset
        )
        let size = CGSize(
            width: spaceSize.width,
            height: Constants.containerViewMinHeight
        )

        let decoration = SingleDecoration.createDecoration(
            on: self,
            containerView: self,
            spaceSize: spaceSize,
            offset: offset,
            size: size
        )
        .round(cornerRadii, mode: .allCorners)
        .fill(R.color.colorBlockBackground()!)

        return [decoration]
    }

    func createSkeletons(for spaceSize: CGSize) -> [any Skeletonable] {
        var lastY: CGFloat = Constants.containerVerticalInset

        let rows = zip(
            Constants.skeletonLineWidths,
            Constants.skeletonLineHeights
        )
        .enumerated()
        .map { index, size in
            let size = CGSize(
                width: size.0,
                height: size.1
            )

            let yPoint = lastY + Constants.skeletonYOffsets[index]
            lastY = yPoint + size.height

            let offset = CGPoint(
                x: Constants.contentLeadingOffset,
                y: yPoint
            )

            return SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: offset,
                size: size
            )
        }

        return rows
    }
}

// MARK: Internal

extension BannersViewLayout {
    func setBackgroundImage(_ image: UIImage?) {
        backgroundView.setBackground(image)
    }

    func setCloseButton(available: Bool) {
        closeButton.isHidden = !available
    }

    func setLoading() {
        loadingState.formUnion(.content)
    }

    func setLoaded() {
        loadingState.remove(.content)
    }

    func restartLoadingIfNeeded() {
        if loadingState != .none {
            updateLoadingState()
            skeletonView?.restartSkrulling()
        }
    }
}

extension BannersViewLayout {
    struct LoadingState: OptionSet {
        typealias RawValue = UInt8

        static let content = LoadingState(rawValue: 1 << 0)
        static let all: LoadingState = [.content]
        static let none: LoadingState = []

        let rawValue: UInt8

        init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
}

// MARK: Constants

extension BannersViewLayout {
    enum Constants {
        static let contentMinHeight: CGFloat = BannerView.Constants.contentImageViewHeight
        static let containerViewMinHeight: CGFloat = contentMinHeight - containerVerticalInset * 2
        static let pageControlHeight: CGFloat = ExtendedPageControl.Constants.dotSize
        static let totalMinHeight: CGFloat = contentMinHeight + pageControlHeight

        static let closeButtonSize: CGFloat = 24
        static let closeButtontopOffset: CGFloat = 10

        static let backgroundCornerRaius: CGFloat = 12
        static let borderWidth: CGFloat = 1.0

        static let contentLeadingOffset: CGFloat = 16.0
        static let containerVerticalInset: CGFloat = 8.0

        static let skeletonYOffsets: [CGFloat] = [16.0, 10.0, 6.0]
        static let skeletonLineHeights: [CGFloat] = [14.0, 8.0, 8.0]
        static let skeletonLineWidths: [CGFloat] = [168.0, 125.0, 89.0]
        static let skeletonViewHeight: CGFloat = 80.0
    }
}
