import UIKit
import UIKit_iOS

class DAppBrowserTabCollectionCell: CollectionViewContainerCell<DAppBrowserTabView> {
    override func prepareForReuse() {
        super.prepareForReuse()

        view.viewModel?.icon?.cancel(on: view.iconName.imageView)
        view.iconName.imageView.image = nil
        view.iconName.detailsLabel.text = nil
        view.viewModel = nil
    }
}

protocol DAppBrowserTabViewDelegate: AnyObject {
    func actionCloseTab(with id: UUID)
}

class DAppBrowserTabView: UIView {
    weak var delegate: DAppBrowserTabViewDelegate?

    let imageView: BorderedImageView = .create { view in
        view.borderView.cornerRadius = Constants.tabCornerRadius
        view.borderView.strokeWidth = Constants.strokeWidth
        view.borderView.strokeColor = R.color.colorContainerBorder()!
        view.contentMode = .scaleAspectFill
        view.layer.cornerRadius = Constants.tabCornerRadius
        view.clipsToBounds = true
    }

    let closeButton: TriangularedButton = .create { view in
        view.imageWithTitleView?.spacingBetweenLabelAndIcon = 0
        view.contentInsets = Constants.closeButtonContentInsets
        view.imageWithTitleView?.iconImage = R.image.iconCloseWithBgOpaque()
        view.triangularedView?.fillColor = .clear
        view.triangularedView?.shadowOpacity = 0.0
        view.triangularedView?.highlightedFillColor = .clear
        view.triangularedView?.highlightedStrokeColor = .clear
    }

    let iconName: IconDetailsView = .create { view in
        view.detailsLabel.apply(style: .caption1Primary)
        view.detailsLabel.textAlignment = .center
        view.spacing = Constants.iconNameSpacing
        view.iconWidth = Constants.iconSize
    }

    var viewModel: DAppBrowserTabViewModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupActions()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: DAppBrowserTabView

private extension DAppBrowserTabView {
    func setupLayout() {
        addSubview(iconName)
        iconName.snp.makeConstraints { make in
            make.bottom.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
            make.height.equalTo(Constants.iconNameHeight)
        }

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(iconName.snp.top).offset(Constants.iconNameTopOffset)
        }

        addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.closeButtonSize)
            make.top.leading.equalToSuperview()
        }
    }

    func setupActions() {
        closeButton.addTarget(
            self,
            action: #selector(actionClose),
            for: .touchUpInside
        )
    }

    func updateRender() {
        viewModel?.stateRender?.loadImage(
            on: imageView,
            settings: .init(
                targetSize: imageView.intrinsicContentSize,
                cornerRadius: Constants.tabCornerRadius
            ),
            animated: false
        )
    }

    func updateIcon() {
        if let iconModel = viewModel?.icon {
            iconName.iconWidth = Constants.iconSize
            iconName.spacing = Constants.iconNameSpacing

            iconModel.loadImage(
                on: iconName.imageView,
                settings: .init(
                    targetSize: CGSize(
                        width: Constants.iconSize,
                        height: Constants.iconSize
                    ),
                    cornerRadius: Constants.tabCornerRadius
                ),
                animated: false
            )
        } else {
            iconName.iconWidth = 0
            iconName.spacing = 0
        }
    }

    @objc func actionClose() {
        guard let viewModel else { return }

        delegate?.actionCloseTab(with: viewModel.uuid)
    }
}

// MARK: Interface

extension DAppBrowserTabView {
    func bind(
        viewModel: DAppBrowserTabViewModel,
        delegate: DAppBrowserTabViewDelegate?
    ) {
        self.viewModel = viewModel
        self.delegate = delegate

        updateRender()
        updateIcon()

        iconName.detailsLabel.text = viewModel.name
    }
}

// MARK: Constants

private extension DAppBrowserTabView {
    enum Constants {
        static let tabCornerRadius: CGFloat = 16.0
        static let closeButtonCornerRadius: CGFloat = closeButtonSize / 2
        static let closeButtonSize: CGFloat = 40.0
        static let iconNameSpacing: CGFloat = 4.0
        static let iconNameHeight: CGFloat = 16.0
        static let iconSize: CGFloat = 15
        static let iconNameTopOffset: CGFloat = -8
        static let strokeWidth: CGFloat = 2.0
        static let closeButtonContentInsets = UIEdgeInsets(
            top: 8.0,
            left: 8.0,
            bottom: 8.0,
            right: 8.0
        )
    }
}
