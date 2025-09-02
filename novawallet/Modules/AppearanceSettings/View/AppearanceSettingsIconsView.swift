import UIKit
import UIKit_iOS

class AppearanceSettingsIconsView: UIView {
    private var optionChangedAction: ((AppearanceOptions) -> Void)?
    private var selectedOption: AppearanceOptions?

    private let whiteOptionImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.layer.masksToBounds = true
        view.layer.cornerRadius = Constants.imageSize / 2
        view.layer.borderWidth = Constants.selectedBorderWidth
        view.layer.borderColor = UIColor.clear.cgColor

        view.image = R.image.iconAppearanceWhite()
    }

    private let coloredOptionImageView: UIImageView = .create { view in
        view.contentMode = .scaleAspectFit
        view.layer.masksToBounds = true
        view.layer.cornerRadius = Constants.imageSize / 2
        view.layer.borderWidth = Constants.selectedBorderWidth
        view.layer.borderColor = UIColor.clear.cgColor

        view.image = R.image.iconAppearanceColored()
    }

    private let tokenIconsView: GenericMultiValueView<
        GenericBorderedView<
            GenericPairValueView<
                GenericPairValueView<
                    UIView,
                    UILabel
                >,
                GenericPairValueView<
                    UIView,
                    UILabel
                >
            >
        >
    > = .create { view in
        view.spacing = Constants.titleContainerSpacing

        view.valueTop.apply(style: .semiboldCaps2Secondary)
        view.valueTop.textAlignment = .left

        view.valueBottom.contentInsets = Constants.contentInsets
        view.valueBottom.backgroundView.cornerRadius = Constants.containerCornerRadius
        view.valueBottom.backgroundView.fillColor = R.color.colorBlockBackground()!

        view.valueBottom.contentView.makeHorizontal()
        [
            view.valueBottom.contentView.fView,
            view.valueBottom.contentView.sView
        ]
        .forEach { optionView in
            optionView.setVerticalAndSpacing(Constants.optionInnerSpacing)
            optionView.sView.apply(style: .footnoteSecondary)
            optionView.sView.textAlignment = .center

            optionView.isUserInteractionEnabled = true
        }

        view.valueBottom.contentView.stackView.alignment = .center
        view.valueBottom.contentView.stackView.distribution = .fillEqually
    }

    var tokenIconsSectionTitle: UILabel {
        tokenIconsView.valueTop
    }

    var whiteOption: GenericPairValueView<
        UIView,
        UILabel
    > {
        tokenIconsView.valueBottom.contentView.fView
    }

    var coloredOption: GenericPairValueView<
        UIView,
        UILabel
    > {
        tokenIconsView.valueBottom.contentView.sView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupActions()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: Model) {
        setup(for: viewModel.selectedOption)
    }

    func addAction(on optionChanged: @escaping (AppearanceOptions) -> Void) {
        optionChangedAction = optionChanged
    }

    func applyLocalization(for locale: Locale) {
        let languages = locale.rLanguages

        tokenIconsSectionTitle.text = R.string.localizable.settingsAppearanceTokenIconsTitle(
            preferredLanguages: languages
        ).uppercased()

        whiteOption.sView.text = R.string.localizable.settingsAppearanceTokenIconsOptionWhite(
            preferredLanguages: languages
        )

        coloredOption.sView.text = R.string.localizable.settingsAppearanceTokenIconsOptionColored(
            preferredLanguages: languages
        )
    }
}

// MARK: ViewModel

extension AppearanceSettingsIconsView {
    struct Model {
        let selectedOption: AppearanceOptions
    }

    enum AppearanceOptions {
        case white
        case colored

        init(from iconsOptions: AppearanceIconsOptions) {
            switch iconsOptions {
            case .white:
                self = .white
            case .colored:
                self = .colored
            }
        }
    }
}

// MARK: Private

private extension AppearanceSettingsIconsView {
    func setupLayout() {
        addSubview(tokenIconsView)

        tokenIconsView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        whiteOption.fView.addSubview(whiteOptionImageView)
        coloredOption.fView.addSubview(coloredOptionImageView)

        [whiteOptionImageView, coloredOptionImageView].forEach { imageView in
            imageView.snp.makeConstraints { make in
                make.size.equalTo(Constants.imageSize)
                make.top.bottom.equalToSuperview()
                make.centerX.equalToSuperview()
            }
        }
    }

    func setupActions() {
        whiteOption.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(whiteSelected))
        )

        coloredOption.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(coloredSelected))
        )
    }

    func setup(for selectedOption: AppearanceOptions) {
        self.selectedOption = selectedOption

        switch selectedOption {
        case .white:
            whiteOptionImageView.layer.borderColor = R.color.colorIconAccent()?.cgColor
            coloredOptionImageView.layer.borderColor = UIColor.clear.cgColor

            whiteOption.sView.textColor = R.color.colorButtonTextAccent()
            coloredOption.sView.textColor = R.color.colorTextSecondary()
        case .colored:
            coloredOptionImageView.layer.borderColor = R.color.colorIconAccent()?.cgColor
            whiteOptionImageView.layer.borderColor = UIColor.clear.cgColor

            coloredOption.sView.textColor = R.color.colorButtonTextAccent()
            whiteOption.sView.textColor = R.color.colorTextSecondary()
        }
    }

    @objc func whiteSelected() {
        changeOption(to: .white)
    }

    @objc func coloredSelected() {
        changeOption(to: .colored)
    }

    func changeOption(to newOption: AppearanceOptions) {
        guard selectedOption != newOption else {
            return
        }

        selectedOption = newOption

        setup(for: newOption)
        optionChangedAction?(newOption)
    }
}

// MARK: Constants

private extension AppearanceSettingsIconsView {
    enum Constants {
        static let imageSize: CGFloat = 56
        static let containerCornerRadius: CGFloat = 10
        static let selectedBorderWidth: CGFloat = 1.0

        static let contentInsets: UIEdgeInsets = .init(
            top: 16,
            left: 16,
            bottom: 16,
            right: 16
        )

        static let optionInnerSpacing: CGFloat = 4
        static let titleContainerSpacing: CGFloat = 12
    }
}
