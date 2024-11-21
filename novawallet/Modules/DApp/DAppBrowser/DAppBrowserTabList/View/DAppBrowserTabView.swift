import UIKit
import SoraUI

typealias DAppBrowserTabCollectionCell = CollectionViewContainerCell<DAppBrowserTabView>

class DAppBrowserTabView: UIView {
    let imageView: BorderedImageView = .create { view in
        view.borderView.cornerRadius = Constants.tabCornerRadius
        view.borderView.strokeWidth = Constants.strokeWidth
        view.borderView.strokeColor = R.color.colorContainerBorder()!
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = Constants.tabCornerRadius
        view.clipsToBounds = true
    }

    let closeButton: RoundedButton = .create { view in
        view.roundedBackgroundView?.cornerRadius = Constants.closeButtonCornerRadius
        view.contentInsets = Constants.closeButtonContentInsets
        view.imageWithTitleView?.iconImage = R.image.iconClose()?.tinted(
            with: R.color.colorIconCloseDApp()!
        )
        view.roundedBackgroundView?.fillColor = R.color.colorCloseDAppBackground()!
        view.roundedBackgroundView?.shadowOpacity = 0.0
    }

    let nameLabel: ImageWithTitleView = .create { view in
        view.spacingBetweenLabelAndIcon = Constants.iconLabelSpacing
        view.titleFont = .caption1
        view.titleColor = R.color.colorTextPrimary()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension DAppBrowserTabView {
    func setupLayout() {
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
        }

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(nameLabel.snp.top).offset(Constants.nameLabelTopOffset)
        }

        addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.closeButtonSize)
            make.top.leading.equalToSuperview().inset(Constants.closeButtonEdgeInsets)
        }
    }
}

extension DAppBrowserTabView {
    func bind(viewModel: DAppBrowserTab) {
        if let imageData = viewModel.stateRender {
            imageView.image = UIImage(data: imageData)
        }

        nameLabel.title = viewModel.name
    }
}

private extension DAppBrowserTabView {
    enum Constants {
        static let tabCornerRadius: CGFloat = 16.0
        static let closeButtonCornerRadius: CGFloat = closeButtonSize / 2
        static let closeButtonSize: CGFloat = 20.0
        static let iconLabelSpacing: CGFloat = 4.0
        static let nameLabelTopOffset: CGFloat = -8
        static let closeButtonEdgeInsets: CGFloat = 10.0
        static let strokeWidth: CGFloat = 2.0
        static let closeButtonContentInsets = UIEdgeInsets(
            top: 5.6,
            left: 5.6,
            bottom: 5.6,
            right: 5.6
        )
    }
}
