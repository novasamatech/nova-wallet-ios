import UIKit
import SoraUI

class IconDetailsGenericView<Details: UIView>: UIView {
    enum Mode {
        case iconDetails
        case detailsIcon
    }

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        return imageView
    }()

    let detailsView: Details

    var mode: Mode = .iconDetails {
        didSet {
            applyLayout()
        }
    }

    var spacing: CGFloat {
        get {
            stackView.spacing
        }

        set {
            stackView.spacing = newValue
        }
    }

    private(set) var stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.spacing = 8.0
        view.alignment = .center
        return view
    }()

    var iconWidth: CGFloat = 16.0 {
        didSet {
            imageView.snp.updateConstraints { make in
                make.width.equalTo(iconWidth)
            }

            setNeedsLayout()
        }
    }

    init(detailsView: Details = Details()) {
        self.detailsView = detailsView

        super.init(frame: .zero)

        setupLayout()
    }

    override init(frame: CGRect) {
        detailsView = Details()

        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        guard imageView.superview == nil else {
            return
        }

        setupLayout()
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        imageView.snp.makeConstraints { make in
            make.width.equalTo(iconWidth)
        }

        applyLayout()
    }

    private func applyLayout() {
        imageView.removeFromSuperview()
        detailsView.removeFromSuperview()

        switch mode {
        case .iconDetails:
            stackView.addArrangedSubview(imageView)
            stackView.addArrangedSubview(detailsView)
        case .detailsIcon:
            stackView.addArrangedSubview(detailsView)
            stackView.addArrangedSubview(imageView)
        }
    }
}

extension IconDetailsGenericView: Highlightable {
    func set(highlighted: Bool, animated: Bool) {
        imageView.set(highlighted: highlighted, animated: animated)

        if let highlightableDetails = detailsView as? Highlightable {
            highlightableDetails.set(highlighted: highlighted, animated: animated)
        }
    }
}
