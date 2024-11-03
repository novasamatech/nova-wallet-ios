import UIKit
import SoraUI

final class QRDisplayView: UIView {
    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.fillColor = .white
        view.cornerRadius = 24.0
        return view
    }()

    let noLogoQRImageView = UIImageView()
    let fullQRImageView: UIImageView = .create { view in
        view.alpha = 0
    }

    var viewModel: QRCodeWithLogoFactory.QRCreationResult?

    var contentInsets: CGFloat = 8.0 {
        didSet {
            [noLogoQRImageView, fullQRImageView].forEach {
                $0.snp.updateConstraints { make in
                    make.edges.equalToSuperview().inset(contentInsets)
                }
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

    func bind(viewModel: QRCodeWithLogoFactory.QRCreationResult) {
        switch viewModel {
        case let .noLogo(image):
            noLogoQRImageView.image = image
        case let .full(image) where self.viewModel != nil && self.viewModel != viewModel:
            fullQRImageView.image = image

            UIView.animate(withDuration: 0.3) {
                self.fullQRImageView.alpha = 1
            }
        case let .full(image):
            fullQRImageView.image = image
            fullQRImageView.alpha = 1
        }

        self.viewModel = viewModel
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        [
            noLogoQRImageView,
            fullQRImageView
        ]
        .forEach { view in
            addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }
}
