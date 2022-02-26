import UIKit
import SoraUI

final class NftMediaView: RoundedView {
    let contentView: UIImageView = {
        UIImageView()
    }()

    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            if oldValue != contentInsets {
                updateLayout()

                if skeletonView != nil {
                    setupSkeleton()
                }
            }
        }
    }

    private var viewModel: NftMediaViewModelProtocol?
    private var mediaSettings: NftMediaDisplaySettings?
    private var lastError: Error?

    private var skeletonView: SkrullableView?

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

        if skeletonView != nil {
            setupSkeleton()
        }
    }

    func bind(viewModel: NftMediaViewModelProtocol, targetSize: CGSize, cornerRadius: CGFloat) {
        self.viewModel?.cancel(on: contentView)
        contentView.image = nil

        self.viewModel = viewModel

        mediaSettings = NftMediaDisplaySettings(targetSize: targetSize, cornerRadius: cornerRadius, animated: true)
        loadMedia()
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

        if contentView.image == nil {
            startSkeletonIfNeeded()
        }

        viewModel?.loadMedia(on: contentView, displaySettings: mediaSettings) { [weak self] optionalError in
            self?.lastError = optionalError

            if self?.contentView.image != nil {
                self?.stopSkeletonIfNeeded()
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
        guard skeletonView == nil else {
            return
        }

        contentView.alpha = 0.0

        setupSkeleton()
    }

    func stopSkeletonIfNeeded() {
        guard skeletonView != nil else {
            return
        }

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
            targetSize: mediaSettings.targetSize,
            cornerRadius: mediaSettings.cornerRadius
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
}
