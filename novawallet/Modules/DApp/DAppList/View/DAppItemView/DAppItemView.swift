import UIKit

final class DAppItemView: UIView {
    let iconImageView: DAppIconView = .create {
        $0.contentInsets = Constants.iconInsets
        $0.backgroundView.apply(style: .roundedContainer(radius: Constants.iconRadius))
    }

    let favoriteImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.image = R.image.iconFavButtonSel()?.tinted(
            with: R.color.colorIconMiniFavorite()!
        )
    }

    let titleView: MultiValueView = .create { view in
        view.spacing = Constants.titleSubtitleSpace
    }

    private var model: DAppViewModel?

    var layoutStyle: LayoutStyle = .horizontal {
        didSet {
            setupLayout()
            setupStyle()

            if let model {
                bind(model)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension DAppItemView {
    func setupLayout() {
        iconImageView.snp.makeConstraints {
            $0.size.equalTo(Constants.preferredIconViewSize)
        }

        switch layoutStyle {
        case .horizontal: layoutHorizontal()
        case .vertical: layoutVertical()
        }

        addSubview(favoriteImageView)
        favoriteImageView.snp.makeConstraints { make in
            make.size.equalTo(Constants.favoriteIconSize)
            make.top.equalTo(iconImageView.snp.top).inset(-2)
            make.trailing.equalTo(iconImageView.snp.trailing).inset(-4.0)
        }
    }

    func layoutHorizontal() {
        subviews.forEach { $0.removeFromSuperview() }

        let content = UIView.hStack(
            alignment: .center,
            distribution: .fillProportionally,
            spacing: Constants.horizontalSpace,
            [
                iconImageView,
                titleView
            ]
        )

        titleView.stackView.alignment = .leading

        addSubview(content)

        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func layoutVertical() {
        subviews.forEach { $0.removeFromSuperview() }

        let content = UIView.vStack(
            alignment: .center,
            spacing: Constants.verticalSpace,
            [
                iconImageView,
                titleView
            ]
        )

        titleView.stackView.alignment = .center

        addSubview(content)

        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }

    func setupStyle() {
        switch layoutStyle {
        case .horizontal: styleHorizontal()
        case .vertical: styleVertical()
        }
    }

    func styleVertical() {
        titleView.valueTop.apply(style: .caption1Secondary)
    }

    func styleHorizontal() {
        titleView.valueTop.apply(style: .regularSubhedlinePrimary)
    }

    func bind(_ model: DAppViewModel) {
        titleView.valueTop.text = model.name

        iconImageView.bind(
            viewModel: model.icon,
            size: Constants.iconSize
        )

        if model.isFavorite {
            favoriteImageView.isHidden = false
        } else {
            favoriteImageView.isHidden = true
        }

        switch layoutStyle {
        case .horizontal:
            titleView.valueBottom.text = model.details
        case .vertical:
            titleView.valueBottom.text = nil
        }
    }
}

// MARK: - Model

extension DAppItemView {
    struct Model {
        let icon: ImageViewModelProtocol?
        let title: String
        let subtitle: String
    }

    func bind(viewModel: DAppViewModel) {
        bind(viewModel)

        model = viewModel
    }

    func clear() {
        model?.icon?.cancel(on: iconImageView.imageView)
    }
}

// MARK: - Constants

extension DAppItemView {
    enum Constants {
        static let arrowSize = CGSize(width: 16, height: 16)
        static let titleSubtitleSpace: CGFloat = 4
        static let horizontalSpace: CGFloat = 12
        static let verticalSpace: CGFloat = 8
        static let iconRadius: CGFloat = 12

        static let iconSize = CGSize(
            width: 36,
            height: 36
        )
        static let iconInsets = UIEdgeInsets(
            top: 6,
            left: 6,
            bottom: 6,
            right: 6
        )
        static var preferredIconViewSize = CGSize(
            width: iconInsets.left + iconSize.width + iconInsets.right,
            height: iconInsets.top + iconSize.height + iconInsets.bottom
        )

        static var favoriteIconSize = CGSize(
            width: 12,
            height: 12
        )
    }

    enum LayoutStyle {
        case horizontal
        case vertical
    }
}
