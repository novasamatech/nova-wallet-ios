import UIKit

final class UnifiedAddressPopupViewLayout: UIView {
    private let titleValueView: MultiValueView = .create { view in
        view.valueTop.apply(style: .boldTitle3Primary)
        view.valueBottom.apply(style: .footnoteSecondary)
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

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Constants

private extension UnifiedAddressPopupViewLayout {
    enum Constants {
        static let titleValueSpacing: CGFloat = 8.0
        static let addressContainerSpacing: CGFloat = 12.0
    }
}
