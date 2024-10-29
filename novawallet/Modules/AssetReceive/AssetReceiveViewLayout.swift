import UIKit
import SoraUI
import SnapKit

final class AssetReceiveViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = Constants.containerInsets
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .center
        return view
    }()

    let qrContainerView: RoundedView = .create { view in
        view.fillColor = .white
        view.cornerRadius = Constants.qrContainerCornerRadius
    }

    let chainView = AssetListChainView()

    let accountAddressView = AccountAddressView()

    let titleLabel: UILabel = .create { view in
        view.apply(style: .title3Primary)
        view.textAlignment = .center
    }

    let detailsLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
        view.numberOfLines = 0
        view.textAlignment = .center
    }

    let qrView: QRDisplayView = .create {
        $0.contentInsets = Constants.qrViewContentInsets
        $0.backgroundView.shadowOpacity = .zero
    }

    let shareButton: TriangularedButton = .create { $0.applyDefaultStyle() }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.addArrangedSubview(detailsLabel)
        containerView.stackView.addArrangedSubview(qrContainerView)

        qrContainerView.addSubview(qrView)
        qrContainerView.addSubview(accountAddressView)

        qrView.snp.makeConstraints {
            $0.width.equalTo(containerView).multipliedBy(Constants.qrViewSizeRatio)
            $0.width.equalTo(Constants.qrViewPlaceHolderWidth).priority(.high)
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(qrView.snp.width)
        }

        accountAddressView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(qrView.snp.bottom).offset(Constants.qrViewContentInsets)
            make.bottom.equalToSuperview().inset(Constants.addressViewBottomInset)
        }

        containerView.stackView.setCustomSpacing(
            Constants.titleDetailsVerticalSpace,
            after: titleLabel
        )
        containerView.stackView.setCustomSpacing(
            Constants.detailsQRVerticalSpace,
            after: detailsLabel
        )

        addSubview(shareButton)
        shareButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            $0.height.equalTo(Constants.shareButtonHeight)
            $0.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }
    }
}

extension AssetReceiveViewLayout {
    enum Constants {
        static let qrContainerCornerRadius: CGFloat = 16
        static let qrViewSizeRatio: CGFloat = 0.8
        static let qrViewPlaceHolderWidth: CGFloat = 280
        static let qrCodeMinimumWidth: CGFloat = 120
        static let detailsQRVerticalSpace: CGFloat = 36
        static let titleDetailsVerticalSpace: CGFloat = 4
        static let qrViewContentInsets: CGFloat = 8
        static let containerHorizontalOffset: CGFloat = 16
        static let shareButtonTopOffset: CGFloat = 24
        static let shareButtonHeight: CGFloat = 52
        static let addressViewBottomInset: CGFloat = 12
        static let containerInsets = UIEdgeInsets(
            top: 40,
            left: containerHorizontalOffset,
            bottom: Constants.shareButtonHeight + shareButtonTopOffset,
            right: containerHorizontalOffset
        )

        static let calculateQRsize: (CGFloat) -> CGSize? = { boundsWidth in
            let width = qrViewSizeRatio * boundsWidth - qrViewContentInsets * 2
            guard width >= qrCodeMinimumWidth else {
                return nil
            }
            return .init(width: width, height: width)
        }
    }
}
