import UIKit
import UIKit_iOS

final class YourWalletsControl: BaseActionControl {
    var color = R.color.colorButtonTextAccent()! {
        didSet {
            iconDetailsView.detailsLabel.textColor = color
            imageActionIndicator.image = R.image.iconLinkChevron()?.tinted(with: color)
        }
    }

    lazy var iconDetailsView: YourWalletsIconDetailsView = .create {
        $0.detailsLabel.textColor = color
        $0.detailsLabel.font = .caption1
        $0.spacing = 5
        $0.isUserInteractionEnabled = false
    }

    lazy var imageActionIndicator: ImageActionIndicator = .create {
        $0.image = R.image.iconLinkChevron()?.tinted(with: color)
        $0.identityIconAngle = CGFloat.pi / 2.0
        $0.activationIconAngle = -CGFloat.pi / 2.0
        $0.isUserInteractionEnabled = false
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
        title = iconDetailsView
        indicator = imageActionIndicator
        horizontalSpacing = 0
        contentInsets = .init(top: 5, left: 0, bottom: 5, right: 0)
    }
}

extension YourWalletsControl {
    struct Model {
        let name: String
        let image: UIImage?
    }

    func bind(model: Model) {
        iconDetailsView.detailsLabel.text = model.name
        iconDetailsView.imageView.image = model.image?.withRenderingMode(.alwaysTemplate).tinted(with: color)

        invalidateLayout()
        setNeedsLayout()
    }
}

extension YourWalletsControl {
    enum State {
        case hidden
        case active
        case inactive
    }

    func apply(state: State) {
        switch state {
        case .hidden:
            isHidden = true
            deactivate(animated: false)
        case .active:
            isHidden = false
            activate(animated: true)
        case .inactive:
            isHidden = false
            deactivate(animated: true)
        }
        invalidateLayout()
        setNeedsLayout()
    }
}
