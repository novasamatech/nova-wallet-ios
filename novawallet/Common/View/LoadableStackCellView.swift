import UIKit

final class LoadableStackActionView<TitleView: UIView>: UIView {
    let titleView = TitleView()

    let activityIndicator: UIActivityIndicatorView = .create { view in
        view.style = .medium
        view.tintColor = R.color.colorWhite()
        view.hidesWhenStopped = true
    }

    let disclosureIndicatorView: UIImageView = .create { imageView in
        imageView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorTransparentText()!)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func startLoading() {
        disclosureIndicatorView.isHidden = true
        activityIndicator.startAnimating()
    }

    func stopLoading() {
        disclosureIndicatorView.isHidden = false
        activityIndicator.stopAnimating()
    }

    private func setupLayout() {
        addSubview(activityIndicator)

        activityIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        addSubview(disclosureIndicatorView)
        disclosureIndicatorView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        activityIndicator.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        disclosureIndicatorView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()

            let offset: CGFloat = 4.0

            make.trailing.lessThanOrEqualTo(activityIndicator.snp.leading).offset(offset)
            make.trailing.lessThanOrEqualTo(disclosureIndicatorView.snp.leading).offset(offset)
        }
    }
}
