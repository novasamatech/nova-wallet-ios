import UIKit

class BlurredView<TContentView>: UIView where TContentView: UIView {
    let view: TContentView
    let backgroundBlurView = TriangularedBlurView()

    var contentInsets: UIEdgeInsets = .init(top: 0, left: 0, bottom: 0, right: 0) {
        didSet {
            updateLayout()
        }
    }

    var innerInsets: UIEdgeInsets = .zero {
        didSet {
            updateLayout()
        }
    }

    init(view: TContentView = .init()) {
        self.view = view
        super.init(frame: .zero)
        backgroundColor = .clear
        setupLayout()
    }

    override init(frame: CGRect) {
        view = TContentView()
        super.init(frame: frame)
        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        .init(width: UIView.noIntrinsicMetric, height: 123)
    }

    private func setupLayout() {
        addSubview(backgroundBlurView)
        backgroundBlurView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }

        backgroundBlurView.addSubview(view)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(innerInsets)
        }
    }

    private func updateLayout() {
        backgroundBlurView.snp.updateConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
        view.snp.updateConstraints {
            $0.edges.equalToSuperview().inset(innerInsets)
        }
    }
}
