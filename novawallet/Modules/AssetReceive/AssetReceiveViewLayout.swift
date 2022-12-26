import UIKit
import SnapKit

final class AssetReceiveViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = Constants.containerInsets
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .center
        return view
    }()

    let accountDetailsView: ChainAccountControl = .create {
        $0.chainAccountView.actionIconView.image = R.image.iconMore()?.tinted(with: R.color.colorIconSecondary()!)
    }

    let titleLabel = UILabel(style: .semiBoldBodyPrimary, textAlignment: .center)
    let qrView: QRDisplayView = .create { $0.contentInsets = Constants.qrViewContentInsets }
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
        containerView.stackView.addArrangedSubview(accountDetailsView)
        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.addArrangedSubview(qrView)

        accountDetailsView.snp.makeConstraints {
            $0.height.equalTo(Constants.accountDetailsViewHeight)
            $0.width.equalToSuperview().inset(Constants.containerHorizontalOffset)
        }

        qrView.snp.makeConstraints {
            $0.width.equalToSuperview().multipliedBy(Constants.qrViewSizeRatio)
            $0.width.equalTo(Constants.qrViewPlaceHolderWidth).priority(.high)
            $0.height.equalTo(qrView.snp.width)
        }

        containerView.stackView.setCustomSpacing(
            Constants.accountDetailsTitleVerticalSpace,
            after: accountDetailsView
        )
        containerView.stackView.setCustomSpacing(Constants.titleQRVerticalSpace, after: titleLabel)

        addSubview(shareButton)
        shareButton.snp.makeConstraints {
            $0.top.equalTo(qrView.snp.bottom).offset(Constants.shareButtonTopOffset).priority(.high)
            $0.leading.equalTo(qrView.snp.leading)
            $0.trailing.equalTo(qrView.snp.trailing)
            $0.height.equalTo(Constants.shareButtonHeight)
            $0.bottom.lessThanOrEqualTo(safeAreaLayoutGuide.snp.bottom)
        }
    }
}

extension AssetReceiveViewLayout {
    enum Constants {
        static let qrViewSizeRatio: CGFloat = 0.75
        static let qrViewPlaceHolderWidth: CGFloat = 280
        static let accountDetailsViewHeight: CGFloat = 52
        static let accountDetailsTitleVerticalSpace: CGFloat = 52
        static let titleQRVerticalSpace: CGFloat = 36
        static let qrViewContentInsets: CGFloat = 8
        static let containerHorizontalOffset: CGFloat = 16
        static let shareButtonTopOffset: CGFloat = 24
        static let shareButtonHeight: CGFloat = 52
        static let containerInsets = UIEdgeInsets(
            top: 16,
            left: containerHorizontalOffset,
            bottom: Constants.shareButtonHeight + shareButtonTopOffset,
            right: containerHorizontalOffset
        )

        static let calculateQRsize: (CGRect) -> CGSize = { bounds in
            let width = qrViewSizeRatio * bounds.width - qrViewContentInsets * 2
            let adjustedWidth = max(width, qrViewPlaceHolderWidth)
            return .init(width: adjustedWidth, height: adjustedWidth)
        }
    }
}
