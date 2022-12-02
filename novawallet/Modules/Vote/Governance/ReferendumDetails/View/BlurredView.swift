import UIKit

class BlurredView<TContentView>: UIView where TContentView: UIView {
    let view: TContentView = .init()
    let backgroundBlurView = BlockBackgroundView()

    var contentInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16) {
        didSet {
            updateLayout()
        }
    }

    var innerInsets: UIEdgeInsets = .zero {
        didSet {
            updateLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
