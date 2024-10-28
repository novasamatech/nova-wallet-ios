import UIKit
import SoraUI

class AppearanceSettingsIconsView: UIView {
    private let tokenIconsView: GenericMultiValueView<
        GenericBorderedView<
            GenericPairValueView<
                GenericPairValueView<
                    UIImageView,
                    UILabel
                >,
                GenericPairValueView<
                    UIImageView,
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
            optionView.fView.contentMode = .scaleAspectFit
            optionView.sView.apply(style: .footnoteSecondary)
            optionView.sView.textAlignment = .center
        }

        view.valueBottom.contentView.fView.fView.image = R.image.iconAppearanceWhite()
        view.valueBottom.contentView.sView.fView.image = R.image.iconAppearanceColored()
        view.valueBottom.contentView.stackView.alignment = .center
        view.valueBottom.contentView.stackView.distribution = .fillEqually
    }

    var tokenIconsSectionTitle: UILabel {
        tokenIconsView.valueTop
    }

    var whiteOption: GenericPairValueView<
        UIImageView,
        UILabel
    > {
        tokenIconsView.valueBottom.contentView.fView
    }

    var coloredOption: GenericPairValueView<
        UIImageView,
        UILabel
    > {
        tokenIconsView.valueBottom.contentView.sView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: Model) {
        print(viewModel)
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
        let selectedOption: AppearanceIconsOptions
    }

    enum AppearanceIconsOptions {
        case white
        case colored
    }
}

// MARK: Private

private extension AppearanceSettingsIconsView {
    func setupLayout() {
        addSubview(tokenIconsView)

        tokenIconsView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        [whiteOption.fView, coloredOption.fView].forEach { imageView in
            imageView.snp.makeConstraints { make in
                make.size.equalTo(Constants.imageSize)
            }
        }
    }
}

// MARK: Constants

private extension AppearanceSettingsIconsView {
    enum Constants {
        static let imageSize: CGFloat = 56
        static let containerCornerRadius: CGFloat = 10

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
