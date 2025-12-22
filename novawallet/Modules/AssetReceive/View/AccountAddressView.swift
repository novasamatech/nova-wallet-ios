import Foundation
import UIKit
import UIKit_iOS

final class AccountAddressView: UIView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .regularSubhedlinePrimaryOnWhite)
        view.textAlignment = .center
    }

    let addressLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondaryOnWhite)
        view.textAlignment = .center
        view.numberOfLines = 0
    }

    let copyButton: TriangularedButton = .create { view in
        view.applyEnabledStyle(
            colored: .clear,
            textColor: R.color.colorButtonTextAccent()!
        )

        view.imageWithTitleView?.iconImage = R.image.iconActionCopy()?.tinted(
            with: R.color.colorIconAccent()!
        )?.kf.resize(to: .init(width: 16, height: 16))

        view.imageWithTitleView?.titleFont = .caption1
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let container = UIStackView.vStack(
            alignment: .center,
            spacing: 4,
            [
                titleLabel,
                addressLabel,
                copyButton
            ]
        )

        addSubview(container)

        container.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        copyButton.snp.makeConstraints { make in
            make.height.equalTo(32)
        }
    }
}
