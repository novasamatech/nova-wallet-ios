import UIKit
import UIKit_iOS

class QRScannerViewLayout: UIView {
    let qrFrameView: CameraFrameView = {
        let view = CameraFrameView()
        view.cornerRadius = 24.0
        view.windowSize = CGSize(width: 221.0, height: 221.0)
        view.windowPosition = CGPoint(x: 0.5, y: 0.47)
        view.fillColor = R.color.colorDimBackground()!
        return view
    }()

    let qrFrameImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconQRFrame()
        return imageView
    }()

    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldBodyPrimary)
        view.numberOfLines = 2
        view.textAlignment = .center
    }

    let detailsView: IconDetailsView = .create { view in
        view.detailsLabel.apply(style: .semiboldBodyPrimary)
        view.detailsLabel.numberOfLines = 1
        view.iconWidth = 24
        view.spacing = 2
    }

    let messageLabel: UILabel = .create { view in
        view.apply(style: .semiboldBodyPrimary)
        view.numberOfLines = 0
        view.textAlignment = .center
    }

    var actionButton: TriangularedButton?

    init(settings: QRScannerViewSettings, frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        configure(with: settings)
        setupLayout(with: settings)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure(with settigns: QRScannerViewSettings) {
        if settigns.canUploadFromGallery {
            actionButton = TriangularedButton()
            actionButton?.applyDefaultStyle()
            actionButton?.contentInsets = UIEdgeInsets(top: 0, left: 42, bottom: 0, right: 42)
        }
    }

    func setupLayout(with settings: QRScannerViewSettings) {
        addSubview(qrFrameView)

        qrFrameView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()

            if settings.extendsUnderSafeArea {
                make.top.equalToSuperview()
            } else {
                make.top.equalTo(safeAreaLayoutGuide.snp.top)
            }
        }

        qrFrameView.addSubview(qrFrameImageView)

        qrFrameImageView.snp.makeConstraints { make in
            make.centerX.equalTo(qrFrameView.snp.trailing).multipliedBy(qrFrameView.windowPosition.x)
            make.centerY.equalTo(qrFrameView.snp.bottom).multipliedBy(qrFrameView.windowPosition.y)
        }

        addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(qrFrameImageView.snp.top).offset(-24.0)
        }

        addSubview(detailsView)

        detailsView.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.centerX.equalToSuperview()
            make.top.equalTo(qrFrameImageView.snp.bottom).offset(24.0)
        }

        if let actionButton = actionButton {
            addSubview(actionButton)
            actionButton.snp.makeConstraints { make in
                make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
                make.centerX.equalToSuperview()
                make.height.equalTo(UIConstants.actionHeight)
            }
        }

        addSubview(messageLabel)
        messageLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)

            if let actionButton = actionButton {
                make.bottom.equalTo(actionButton.snp.top).offset(-24.0)
            } else {
                make.bottom.equalTo(safeAreaLayoutGuide).offset(-24.0)
            }
        }
    }
}
