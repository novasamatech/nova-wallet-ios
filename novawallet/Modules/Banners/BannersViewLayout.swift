import UIKit
import SoraUI
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

    var skeletonView: SkrullableView? {
        didSet {
            skeletonView?.backgroundColor = R.color.colorBlockBackground()
            skeletonView?.layer.cornerRadius = Constants.backgroundCornerRaius
        }
    }

    let containerView = UIView()

    let backgroundView: BannerBackgroundView = .create { view in
        view.clipsToBounds = true
        view.layer.cornerRadius = Constants.backgroundCornerRaius
        view.layer.borderWidth = Constants.borderWidth
        view.layer.borderColor = R.color.colorContainerBorder()?.cgColor
    }

    let closeButton: RoundedButton = .create { button in
        button.applyIconStyle()
        button.imageWithTitleView?.iconImage = R.image.iconCloseWithBg()!
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

    override func layoutSubviews() {
        super.layoutSubviews()

        if loadingState != .none {
            updateLoadingState()
        }
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
        addSubview(pageControl)
        pageControl.snp.makeConstraints { make in
            make.bottom.centerX.equalToSuperview()
            make.height.equalTo(Constants.pageControlHeight)
        }

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(pageControl.snp.top)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalTo(collectionView).inset(Constants.containerVerticalInset)
        }

        containerView.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.closeButtonSize)
            make.trailing.equalToSuperview().inset(Constants.contentLeadingOffset)
            make.top.equalToSuperview().inset(
                Constants.containerVerticalInset + Constants.closeButtontopOffset
            )
        }

        bringSubviewToFront(collectionView)
    }
}

// MARK: SkeletonableView

extension BannersViewLayout: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [containerView, closeButton]
    }

    func createSkeletons(for spaceSize: CGSize) -> [any Skeletonable] {
        var lastY: CGFloat = 0

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

        static let skeletonYOffsets: [CGFloat] = [16.0, 16.0, 8.0]
        static let skeletonLineHeights: [CGFloat] = [14.0, 8.0, 8.0]
        static let skeletonLineWidths: [CGFloat] = [168.0, 125.0, 89.0]
        static let skeletonViewHeight: CGFloat = 80.0
    }
}
