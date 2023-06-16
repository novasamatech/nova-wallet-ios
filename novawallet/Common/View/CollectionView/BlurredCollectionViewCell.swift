import UIKit

class BlurredCollectionViewCell<TContentView>: UICollectionViewCell where TContentView: UIView {
    let view: BlurredView<TContentView> = .init()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
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

    private func setupStyle() {
        view.backgroundBlurView.overlayView?.fillColor = .clear
        view.backgroundBlurView.overlayView?.highlightedFillColor = R.color.colorCellBackgroundPressed()!
    }

    private func setupLayout() {
        contentView.addSubview(view)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}
