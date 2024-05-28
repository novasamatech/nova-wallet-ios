import UIKit

protocol HiddenMnemonicCardViewDelegate: AnyObject {
    func didTapCardCover()
}

final class HiddenMnemonicCardView: UIView {
    weak var delegate: HiddenMnemonicCardViewDelegate?

    private var coverMessageView: GenericPairValueView<UILabel, UILabel> = .create { view in
        view.makeVertical()
        view.spacing = Constants.coverMessageLabelsSpacing
        view.stackView.alignment = .center
        view.fView.apply(style: .semiboldSubhedlinePrimary)
        view.fView.textAlignment = .center
        view.sView.apply(style: .semiboldFootnoteButtonInactive)
        view.sView.textAlignment = .center
        view.sView.numberOfLines = 0
    }

    private lazy var coverView: UIView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        imageView.image = R.image.cardBlurred()
        imageView.isUserInteractionEnabled = true

        imageView.addSubview(coverMessageView)

        coverMessageView.snp.makeConstraints { make in
            make.centerX.centerY.equalTo(imageView)
            make.leading.trailing.equalTo(imageView).inset(Constants.coverMessageLabelsEdgeInsets)
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapCardCover))
        imageView.addGestureRecognizer(tapGesture)

        return imageView
    }()

    private let mnemonicCardView: MnemonicCardView = .create { view in
        view.isUserInteractionEnabled = false
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
        setupInitialLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showMnemonic(model: MnemonicCardView.Model) {
        addSubview(mnemonicCardView)

        mnemonicCardView.snp.makeConstraints { make in
            make.width.height.equalToSuperview()
        }
        mnemonicCardView.bind(to: model)

        UIView.transition(
            from: coverView,
            to: mnemonicCardView,
            duration: 0.5,
            options: [.transitionFlipFromLeft, .curveEaseInOut]
        ) { [weak self] _ in
            self?.coverView.removeFromSuperview()
        }
    }

    func showCover(model: CoverModel) {
        coverView.removeFromSuperview()
        mnemonicCardView.removeFromSuperview()

        coverMessageView.fView.text = model.title
        coverMessageView.sView.text = model.message

        setupInitialLayout()
    }

    @objc private func didTapCardCover() {
        delegate?.didTapCardCover()
    }
}

// MARK: Model

extension HiddenMnemonicCardView {
    struct CoverModel {
        let title: String
        let message: String
    }

    enum State {
        case mnemonicVisible(model: MnemonicCardView.Model)
        case mnemonicNotVisible(model: CoverModel)
    }
}

private extension HiddenMnemonicCardView {
    func setupInitialLayout() {
        addSubview(coverView)

        coverView.snp.makeConstraints { make in
            make.height.equalTo(Constants.coverViewHeight)
            make.width.height.equalToSuperview()
        }
    }

    func setupStyle() {
        coverView.layer.borderWidth = 1.0
        coverView.layer.borderColor = R.color.colorContainerBorder()?.cgColor
        coverView.layer.cornerRadius = Constants.cardCornerRadius
        coverView.layer.masksToBounds = true
        coverView.clipsToBounds = true
    }
}

private extension HiddenMnemonicCardView {
    enum Constants {
        static let cardCornerRadius: CGFloat = 12.0
        static let coverMessageLabelsSpacing: CGFloat = 8
        static let coverMessageLabelsEdgeInsets: CGFloat = 12
        static let coverViewHeight: CGFloat = 198
    }
}
