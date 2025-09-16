import UIKit
import UIKit_iOS

final class BorderedActionControlView: UIView {
    let control: ActionTitleControl = .create {
        let tintColor = R.color.colorButtonTextAccent()!
        $0.imageView.image = R.image.iconLinkChevron()?.tinted(with: tintColor)
        $0.titleLabel.textColor = tintColor
        $0.titleLabel.font = .semiBoldFootnote
        $0.identityIconAngle = 0
        $0.activationIconAngle = 0
        $0.horizontalSpacing = 0
        $0.imageView.isUserInteractionEnabled = false
    }

    let backgroundView: RoundedView = .create {
        $0.applyFilledBackgroundStyle()
        $0.fillColor = R.color.colorChipsBackground()!
        $0.highlightedFillColor = R.color.colorChipsBackground()!
        $0.cornerRadius = 6
    }

    var contentInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 3) {
        didSet {
            if oldValue != contentInsets {
                updateLayout()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateLayout() {
        control.snp.updateConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        backgroundView.addSubview(control)
        control.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }
    }

    func bind(title: String) {
        control.deactivate(animated: true)
        control.titleLabel.text = title
        control.invalidateLayout()
        setNeedsLayout()
    }
}
