import UIKit
import SoraUI

final class UnifiedAddressPopupViewLayout: UIView {
    private let titleValueView: MultiValueView = .create { view in
        view.valueTop.apply(style: .boldTitle3Primary)
        view.valueBottom.apply(style: .footnoteSecondary)
        view.valueBottom.numberOfLines = 0
        view.valueBottom.textAlignment = .center

        view.stackView.alignment = .center

        view.spacing = Constants.titleValueSpacing
    }

    private let addressContainers: GenericPairValueView<
        UnifiedAddressPopupAddressView,
        UnifiedAddressPopupAddressView
    > = .create { view in
        view.spacing = Constants.addressContainerSpacing
        view.fView.apply(style: .newFormat)
        view.sView.apply(style: .legacyFormat)
    }

    private let checkboxContainer: IconDetailsView = .create { view in
        view.mode = .iconDetails
        view.spacing = Constants.checkboxContainerSpacing
        view.detailsLabel.apply(style: .footnoteSecondary)
        view.iconWidth = Constants.iconSize
        view.imageView.isUserInteractionEnabled = true
    }

    var titleLabel: UILabel {
        titleValueView.valueTop
    }

    var descriptionLabel: UILabel {
        titleValueView.valueBottom
    }

    var newAddressContainer: UnifiedAddressPopupAddressView {
        addressContainers.fView
    }

    var legacyAddressContainer: UnifiedAddressPopupAddressView {
        addressContainers.sView
    }

    var checkBoxImageView: UIImageView {
        checkboxContainer.imageView
    }

    var checkBoxDetailsLabel: UILabel {
        checkboxContainer.detailsLabel
    }

    let button: TriangularedButton = .create {
        $0.applyDefaultStyle()
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

private extension UnifiedAddressPopupViewLayout {
    func setupLayout() {
        addSubview(titleValueView)
        addSubview(addressContainers)
        addSubview(checkboxContainer)
        addSubview(button)

        titleValueView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.interContainerSpacing)
            make.leading.trailing.equalToSuperview().inset(Constants.containerHorizontalInsets)
        }

        addressContainers.snp.makeConstraints { make in
            make.top.equalTo(titleValueView.snp.bottom).inset(-Constants.interContainerSpacing)
            make.leading.trailing.equalToSuperview().inset(Constants.containerHorizontalInsets)
        }

        newAddressContainer.snp.makeConstraints { make in
            make.height.equalTo(Constants.addressContainerHeight)
        }

        legacyAddressContainer.snp.makeConstraints { make in
            make.height.equalTo(Constants.addressContainerHeight)
        }

        checkboxContainer.snp.makeConstraints { make in
            make.top.equalTo(addressContainers.snp.bottom).inset(-Constants.interContainerSpacing)
            make.leading.trailing.equalToSuperview().inset(Constants.containerHorizontalInsets)
            make.height.equalTo(Constants.addressContainerHeight)
        }

        button.snp.makeConstraints { make in
            make.top.equalTo(checkboxContainer.snp.bottom).inset(-Constants.interContainerSpacing)
            make.leading.trailing.equalToSuperview().inset(Constants.containerHorizontalInsets)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }
    }

    func setupStyle() {
        backgroundColor = R.color.colorBottomSheetBackground()
    }
}

// MARK: Internal

extension UnifiedAddressPopupViewLayout {
    func bind(_ viewModel: UnifiedAddressPopup.ViewModel) {
        titleLabel.text = viewModel.titleText
        descriptionLabel.text = viewModel.subtitleText

        newAddressContainer.bind(with: viewModel.newAddress)
        legacyAddressContainer.bind(with: viewModel.legacyAddress)

        checkBoxImageView.image = viewModel.checkboxSelected
            ? R.image.iconCheckbox()
            : R.image.iconCheckboxEmpty()
        checkBoxDetailsLabel.text = viewModel.checkboxText

        button.imageWithTitleView?.title = viewModel.buttonText
    }
}

// MARK: Constants

private extension UnifiedAddressPopupViewLayout {
    enum Constants {
        static let iconSize: CGFloat = 24.0
        static let addressContainerHeight: CGFloat = 64.0

        static let titleValueSpacing: CGFloat = 8.0
        static let addressContainerSpacing: CGFloat = 12.0
        static let checkboxContainerSpacing: CGFloat = 12.0

        static let interContainerSpacing: CGFloat = 16.0
        static let containerHorizontalInsets: CGFloat = 16.0
    }
}
