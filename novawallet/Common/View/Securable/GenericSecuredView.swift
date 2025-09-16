import Foundation
import UIKit

protocol SecurableViewProtocol: AnyObject {
    associatedtype ViewModel
    associatedtype PrivateContentView: UIView

    var privateContentView: PrivateContentView { get }

    func update(with viewModel: ViewModel)
    func createSecureOverlay() -> PrivateContentView
}

extension SecurableViewProtocol where PrivateContentView: UILabel {
    func createSecureOverlay() -> PrivateContentView {
        let view = PrivateContentView()
        view.textAlignment = privateContentView.textAlignment
        view.font = privateContentView.font
        view.textColor = privateContentView.textColor
        view.text = "•••••"

        return view
    }
}

extension SecurableViewProtocol where PrivateContentView: UIImageView {
    func createSecureOverlay() -> PrivateContentView {
        let view = PrivateContentView()
        view.contentMode = privateContentView.contentMode

        return view
    }
}

final class GenericSecuredView<View: UIView & SecurableViewProtocol>: UIView {
    let originalView: View

    private lazy var placeholderImageView: UIImageView = .create {
        $0.contentMode = .scaleAspectFit
    }

    private var overlayView: UIView?

    init(originalView: View = View()) {
        self.originalView = originalView
        super.init(frame: .zero)
        setupLayout()
    }

    override init(frame: CGRect) {
        originalView = View()
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension GenericSecuredView {
    func setupLayout() {
        addSubview(originalView)
        originalView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    func setupPrivacyOverlay(for privacyMode: ViewPrivacyMode) {
        switch privacyMode {
        case .hidden:
            guard let overlayView else { return }

            originalView.privateContentView.alpha = 0

            addSubview(overlayView)
            overlayView.snp.makeConstraints { $0.edges.equalTo(originalView) }
        case .visible:
            overlayView?.removeFromSuperview()

            originalView.privateContentView.alpha = 1
        }
    }
}

// MARK: - Internal

extension GenericSecuredView {
    enum PrivateStyle {
        case dots
        case image(UIImage)
        case hide
    }

    func bind(_ viewModel: SecuredViewModel<View.ViewModel>) {
        originalView.update(with: viewModel.originalContent)
        setupPrivacyOverlay(for: viewModel.privacyMode)
    }

    func configurePrivateStyle(type: PrivateStyle) {
        switch type {
        case .dots:
            overlayView = originalView.createSecureOverlay()
        case let .image(image):
            guard let imageOverlayView = originalView.createSecureOverlay() as? UIImageView else {
                return
            }

            imageOverlayView.image = image

            overlayView = imageOverlayView
        default:
            break
        }
    }
}
