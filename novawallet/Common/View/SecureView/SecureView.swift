import Foundation
import UIKit

enum ViewPrivacyMode {
    case visible
    case hidden
}

class BaseSecureView<View: UIView>: UIView {
    let originalView: View

    private lazy var secureOverlayView: UIView? = {
        createSecureOverlay()
    }()

    init(
        originalView: View = View()
    ) {
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

    func createSecureOverlay() -> UIView? {
        fatalError("Method must be overriden by child class")
    }
}

// MARK: - Private

private extension BaseSecureView {
    func setupLayout() {
        setupLayout(for: originalView)
    }

    func showSecureOverlay() {
        originalView.removeFromSuperview()

        setupLayout(for: secureOverlayView)
    }

    func hideSecureOverlay() {
        secureOverlayView?.removeFromSuperview()

        setupLayout(for: originalView)
    }

    func setupLayout(for contentView: UIView?) {
        guard let contentView else { return }

        addSubview(contentView)
        contentView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}

// MARK: - Internal

extension BaseSecureView {
    func bind(_ privacyMode: ViewPrivacyMode) {
        switch privacyMode {
        case .hidden:
            if let secureOverlayView {
                guard secureOverlayView.superview == nil else { return }
                showSecureOverlay()
            } else {
                originalView.removeFromSuperview()
            }
        case .visible:
            guard originalView.superview == nil else { return }

            hideSecureOverlay()
        }
    }
}

// MARK: - DotsSecureView

final class DotsSecureView<View: UIView>: BaseSecureView<View> {
    var privacyModeConfiguration: DotsOverlayView.Configuration = .default

    override func createSecureOverlay() -> UIView? {
        let overlay = DotsOverlayView()
        overlay.configuration = privacyModeConfiguration

        return overlay
    }
}
