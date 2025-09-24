import Foundation
import UIKit

enum ViewPrivacyMode {
    case visible
    case hidden
}

class BaseSecureView<View: UIView>: UIView {
    let originalView: View

    var preferredSecuredHeight: CGFloat? {
        didSet {
            updateOverlayViewLayout(
                with: preferredSecuredHeight,
                oldValue
            )
        }
    }

    private var secureOverlayView: UIView?

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

        setupLayout(
            for: secureOverlayView,
            preferredHeight: preferredSecuredHeight
        )
    }

    func hideSecureOverlay() {
        secureOverlayView?.removeFromSuperview()

        setupLayout(for: originalView)
    }

    func prepareSecureOverlayView() {
        guard secureOverlayView == nil else { return }

        secureOverlayView = createSecureOverlay()
    }

    func setupLayout(
        for contentView: UIView?,
        preferredHeight: CGFloat? = nil
    ) {
        guard let contentView else { return }

        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()

            guard let preferredHeight else { return }

            $0.height.equalTo(preferredHeight)
        }
    }

    func updateOverlayViewLayout(
        with preferredHeight: CGFloat?,
        _ oldValue: CGFloat?
    ) {
        guard let secureOverlayView, secureOverlayView.superview != nil else { return }

        guard let preferredHeight else {
            secureOverlayView.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
            }

            return
        }

        guard oldValue != nil else {
            secureOverlayView.snp.remakeConstraints { make in
                make.edges.equalToSuperview()
                make.height.equalTo(preferredHeight)
            }

            return
        }

        secureOverlayView.snp.updateConstraints { make in
            make.height.equalTo(preferredHeight)
        }
    }
}

// MARK: - Internal

extension BaseSecureView {
    func bind(_ privacyMode: ViewPrivacyMode) {
        switch privacyMode {
        case .hidden:
            prepareSecureOverlayView()

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
