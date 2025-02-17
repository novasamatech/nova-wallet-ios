import UIKit
import SoraUI

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
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(Constants.containerVerticalInset)
        }

        containerView.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.addSubview(pageControl)
        pageControl.snp.makeConstraints { make in
            make.bottom.leading.equalTo(backgroundView).inset(Constants.contentLeadingOffset)
        }

        containerView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.closeButtonSize)
            make.top.equalTo(backgroundView).inset(Constants.closeButtontopOffset)
            make.trailing.equalTo(backgroundView).inset(Constants.contentLeadingOffset)
        }
    }
}

// MARK: SkeletonableView

extension BannersViewLayout: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        [containerView]
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

private extension BannersViewLayout {
    enum Constants {
        static let closeButtonSize: CGFloat = 24
        static let closeButtontopOffset: CGFloat = 10

        static let backgroundCornerRaius: CGFloat = 12
        static let borderWidth: CGFloat = 1.0

        static let contentLeadingOffset: CGFloat = 16.0
        static let containerVerticalInset: CGFloat = 8.0

        static let skeletonYOffsets: [CGFloat] = [16.0, 16.0, 8.0]
        static let skeletonLineHeights: [CGFloat] = [14.0, 8.0, 8.0]
        static let skeletonLineWidths: [CGFloat] = [168.0, 125.0, 89.0]
    }
}
