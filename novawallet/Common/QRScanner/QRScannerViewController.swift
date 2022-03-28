import UIKit
import AVFoundation
import SoraUI
import SoraFoundation

final class QRScannerViewController: UIViewController, ViewHolder {
    typealias RootViewType = QRScannerViewLayout

    let localizedTitle: LocalizableResource<String>
    let localizedMessage: LocalizableResource<String>
    let presenter: QRScannerPresenterProtocol

    var messageVisibilityDuration: TimeInterval = 5.0

    lazy var messageAppearanceAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()
    lazy var messageDissmisAnimator: BlockViewAnimatorProtocol = BlockViewAnimator()

    init(
        title: LocalizableResource<String>,
        message: LocalizableResource<String>,
        presenter: QRScannerPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        localizedTitle = title
        localizedMessage = message
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    deinit {
        invalidateMessageScheduling()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = QRScannerViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        setupHandlers()

        presenter.setup()
    }

    private func setupLocalization() {
        title = localizedTitle.value(for: selectedLocale)
        rootView.titleLabel.text = localizedMessage.value(for: selectedLocale)
        rootView.actionButton.imageWithTitleView?.title = R.string.localizable.qrScanUploadGallery(
            preferredLanguages: selectedLocale.rLanguages
        )
    }

    private func setupHandlers() {
        rootView.actionButton.addTarget(
            self,
            action: #selector(actionUpload),
            for: .touchUpInside
        )
    }

    private func configureVideoLayer(with captureSession: AVCaptureSession) {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = view.layer.bounds

        rootView.qrFrameView.frameLayer = videoPreviewLayer
    }

    // MARK: Message Management

    private func scheduleMessageHide() {
        invalidateMessageScheduling()

        perform(#selector(hideMessage), with: true, afterDelay: messageVisibilityDuration)
    }

    private func invalidateMessageScheduling() {
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(hideMessage),
            object: true
        )
    }

    @objc private func hideMessage() {
        let block: () -> Void = { [weak self] in
            self?.rootView.messageLabel.alpha = 0.0
        }

        messageDissmisAnimator.animate(block: block, completionBlock: nil)
    }

    @objc private func actionUpload() {
        presenter.uploadGallery()
    }
}

extension QRScannerViewController: QRScannerViewProtocol {
    func didReceive(session: AVCaptureSession) {
        configureVideoLayer(with: session)
    }

    func present(message: String, animated: Bool) {
        rootView.messageLabel.text = message

        let block: () -> Void = { [weak self] in
            self?.rootView.messageLabel.alpha = 1.0
        }

        if animated {
            messageAppearanceAnimator.animate(block: block, completionBlock: nil)
        } else {
            block()
        }

        scheduleMessageHide()
    }
}

extension QRScannerViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
