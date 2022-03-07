import UIKit
import SoraUI

protocol NftMediaViewDelegate: AnyObject {
    func nftMediaDidLoad(_ view: NftMediaView)
    func nftMediaDidPlaceholderFallback(_ view: NftMediaView)
}

final class NftMediaView: RoundedView {
    let contentView: UIImageView = {
        UIImageView()
    }()

    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            if oldValue != contentInsets {
                updateLayout()

                if isLoading {
                    setupSkeleton()
                }
            }
        }
    }

    weak var delegate: NftMediaViewDelegate?

    private var viewModel: NftMediaViewModelProtocol?
    private var mediaSettings: NftMediaDisplaySettings?
    private var lastError: Error?

    private var skeletonView: SkrullableView?
    private var isLoading: Bool = false

    private var placeholderView: ImagePlaceholderView?

    deinit {
        viewModel?.cancel(on: contentView)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if isLoading {
            setupSkeleton()
        }
    }

    func bind(viewModel: NftMediaViewModelProtocol, targetSize: CGSize? = nil, cornerRadius: CGFloat? = nil) {
        let isAspectFit = contentView.contentMode == .scaleAspectFit
        let newSettings = NftMediaDisplaySettings(
            targetSize: targetSize,
            cornerRadius: cornerRadius,
            animated: true,
            isAspectFit: isAspectFit
        )

        if
            self.viewModel?.identifier != viewModel.identifier ||
            mediaSettings != newSettings {
            self.viewModel?.cancel(on: contentView)
            contentView.image = nil

            self.viewModel = viewModel
            mediaSettings = newSettings

            loadMedia()
        } else {
            refreshMediaIfNeeded()
        }
    }

    func bindPlaceholder() {
        lastError = nil

        contentView.image = nil

        viewModel?.cancel(on: contentView)
        viewModel = nil

        stopSkeletonIfNeeded()
        setupPlaceholderView()
    }

    func refreshMediaIfNeeded() {
        if lastError != nil {
            lastError = nil

            loadMedia()
        }
    }

    private func loadMedia() {
        guard let mediaSettings = mediaSettings else {
            return
        }

        lastError = nil
        contentView.image = nil

        removePlaceholderView()
        startSkeletonIfNeeded()

        viewModel?.loadMedia(
            on: contentView,
            displaySettings: mediaSettings
        ) { [weak self] isResolved, optionalError in
            self?.lastError = optionalError

            if optionalError == nil {
                self?.stopSkeletonIfNeeded()

                if isResolved, let strongSelf = self {
                    strongSelf.delegate?.nftMediaDidLoad(strongSelf)
                }
            }

            if !isResolved {
                self?.stopSkeletonIfNeeded()
                self?.setupPlaceholderView()

                if let strongSelf = self {
                    strongSelf.delegate?.nftMediaDidPlaceholderFallback(strongSelf)
                }
            }
        }
    }

    private func updateLayout() {
        contentView.snp.updateConstraints { make in
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.equalToSuperview().inset(contentInsets.right)
            make.top.equalToSuperview().inset(contentInsets.top)
            make.bottom.equalToSuperview().inset(contentInsets.bottom)
        }
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(contentInsets.left)
            make.trailing.equalToSuperview().inset(contentInsets.right)
            make.top.equalToSuperview().inset(contentInsets.top)
            make.bottom.equalToSuperview().inset(contentInsets.bottom)
        }
    }

    func startSkeletonIfNeeded() {
        guard !isLoading else {
            return
        }

        isLoading = true
        contentView.alpha = 0.0

        setupSkeleton()
    }

    func stopSkeletonIfNeeded() {
        guard isLoading else {
            return
        }

        isLoading = false

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        contentView.alpha = 1.0
    }

    private func setupSkeleton() {
        let spaceSize = frame.size

        guard spaceSize.width > 0, spaceSize.height > 0, let mediaSettings = mediaSettings else {
            return
        }

        let skeletons = createSkeletons(
            for: spaceSize,
            targetSize: mediaSettings.targetSize ?? spaceSize,
            cornerRadius: mediaSettings.cornerRadius ?? 0.0
        )

        let builder = Skrull(size: spaceSize, decorations: [], skeletons: skeletons)

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
            insertSubview(view, aboveSubview: contentView)

            skeletonView = view

            view.startSkrulling()

            currentSkeletonView = view
        }

        currentSkeletonView?.frame = CGRect(origin: .zero, size: spaceSize)
    }

    private func createSkeletons(
        for spaceSize: CGSize,
        targetSize: CGSize,
        cornerRadius: CGFloat
    ) -> [Skeletonable] {
        let skeletonOffset = CGPoint(x: contentInsets.left, y: contentInsets.top)

        let cornerRadii = CGSize(width: cornerRadius / spaceSize.width, height: cornerRadius / spaceSize.height)

        return [
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: skeletonOffset,
                size: targetSize
            ).round(cornerRadii, mode: .allCorners)
        ]
    }

    private func setupPlaceholderView() {
        guard placeholderView == nil else {
            return
        }

        let placeholderView = ImagePlaceholderView()
        addSubview(placeholderView)

        placeholderView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }

        self.placeholderView = placeholderView
    }

    private func removePlaceholderView() {
        guard placeholderView != nil else {
            return
        }

        placeholderView?.removeFromSuperview()
        placeholderView = nil
    }
}
