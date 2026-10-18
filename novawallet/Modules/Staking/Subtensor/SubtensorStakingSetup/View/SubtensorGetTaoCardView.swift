import UIKit
import UIKit_iOS

final class SubtensorGetTaoCardView: UIView {
    let iconView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
    }

    let titleLabel: UILabel = .create { label in
        label.apply(style: .semiboldSubhedlinePrimary)
        label.numberOfLines = 0
    }

    let messageLabel: UILabel = .create { label in
        label.apply(style: .footnoteSecondary)
        label.numberOfLines = 0
    }

    let actionButton: TriangularedButton = .create { button in
        button.applySecondaryDefaultStyle()
    }

    private var iconViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlockBackground()
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorGetTaoViewModel) {
        titleLabel.text = viewModel.title
        messageLabel.text = viewModel.message
        actionButton.imageWithTitleView?.title = viewModel.action
        actionButton.invalidateLayout()
    }

    func bind(iconViewModel: ImageViewModelProtocol?) {
        self.iconViewModel?.cancel(on: iconView)
        self.iconViewModel = iconViewModel

        iconViewModel?.loadImage(
            on: iconView,
            targetSize: CGSize(width: Constants.iconSize, height: Constants.iconSize),
            animated: true
        )
    }

    private func setupLayout() {
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().inset(Constants.contentInset)
            make.size.equalTo(Constants.iconSize)
        }

        let textStack = UIView.vStack(spacing: Constants.textSpacing, [titleLabel, messageLabel])

        addSubview(textStack)
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(Constants.iconSpacing)
            make.trailing.top.equalToSuperview().inset(Constants.contentInset)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.top.equalTo(textStack.snp.bottom).offset(Constants.actionSpacing)
            make.leading.trailing.bottom.equalToSuperview().inset(Constants.contentInset)
            make.height.equalTo(Constants.actionHeight)
        }
    }
}

private extension SubtensorGetTaoCardView {
    enum Constants {
        static let cornerRadius: CGFloat = 12
        static let contentInset: CGFloat = 16
        static let iconSize: CGFloat = 36
        static let iconSpacing: CGFloat = 12
        static let textSpacing: CGFloat = 4
        static let actionSpacing: CGFloat = 16
        static let actionHeight: CGFloat = 52
    }
}
