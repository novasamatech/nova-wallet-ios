import UIKit

final class BackgroundedView<ContentView: UIView>: UIView {
    let contentView = ContentView()
    let backgroundView = TriangularedBlurView()

    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            updateInsets()
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
        addSubview(backgroundView)
        backgroundView.addSubview(contentView)

        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
    }

    private func updateInsets() {
        contentView.snp.updateConstraints {
            $0.edges.equalToSuperview().inset(contentInsets)
        }
    }
}
