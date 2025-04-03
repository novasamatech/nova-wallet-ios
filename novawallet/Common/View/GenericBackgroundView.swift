import UIKit
import UIKit_iOS

/// Class to be used to wrap given `WrappedView` with a view that has defined background with either equal `spacing` or
/// precisly set `contentInsets`
/// `mode: Mode` can be used to adjust how `WrappedView` is positioned within this view
class GenericBackgroundView<WrappedView: UIView>: RoundedView {
    enum Mode {
        case insets
        case centered
    }

    let wrappedView: WrappedView

    var mode: Mode = .insets {
        didSet {
            applyLayout()
        }
    }

    /// Used to set equal spacing around `wrappedView` within bounds of `GenericBackgroundView`
    var spacing: CGFloat = 0 {
        didSet {
            contentInsets = .init(top: spacing, left: spacing, bottom: spacing, right: spacing)
            applyLayout()
        }
    }

    /// Used to setup exact insets for `wrappedView` within bounds of `GenericBackgroundView`
    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            applyLayout()
        }
    }

    init(wrappedView: WrappedView = WrappedView()) {
        self.wrappedView = wrappedView
        super.init(frame: .zero)

        setupLayout()
        setupStyle()
    }

    override init(frame: CGRect) {
        wrappedView = WrappedView()

        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension GenericBackgroundView {
    func applyLayout() {
        wrappedView.removeFromSuperview()
        setupLayout()
    }

    func setupLayout() {
        addSubview(wrappedView)
        switch mode {
        case .insets:
            wrappedView.snp.makeConstraints { make in
                make.leading.equalToSuperview().inset(contentInsets.left)
                make.trailing.equalToSuperview().inset(contentInsets.right)
                make.top.equalToSuperview().inset(contentInsets.top)
                make.bottom.equalToSuperview().inset(contentInsets.bottom)
            }
        case .centered:
            wrappedView.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        }
    }

    func setupStyle() {
        shadowOpacity = 0.0
        strokeWidth = 0.0
        fillColor = .clear
        cornerRadius = 12
        roundingCorners = .allCorners
    }
}
