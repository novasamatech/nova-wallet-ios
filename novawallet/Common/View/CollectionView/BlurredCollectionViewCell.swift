import UIKit

class BlurredCollectionViewCell<TContentView>: UICollectionViewCell where TContentView: UIView {
    let view: BlurredView<TContentView> = .init()

    var shouldApplyHighlighting: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                view.backgroundBlurView.set(highlighted: true, animated: false)
            } else {
                view.backgroundBlurView.set(highlighted: false, animated: oldValue)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(view)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}
