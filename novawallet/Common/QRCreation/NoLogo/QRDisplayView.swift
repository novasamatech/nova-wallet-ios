import UIKit
import UIKit_iOS

final class QRDisplayView: UIView {
    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.fillColor = .white
        view.cornerRadius = 24.0
        return view
    }()

    let imageView = UIImageView()

    var contentInsets: CGFloat = 8.0 {
        didSet {
            imageView.snp.updateConstraints { make in
                make.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }

    var cornerRadius: CGFloat {
        get {
            backgroundView.cornerRadius
        }

        set {
            backgroundView.cornerRadius = newValue
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
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }
    }
}
