import UIKit

final class ListLoadingView: UIView {
    let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.style = .medium
        view.tintColor = R.color.colorWhite()
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        label.textAlignment = .center
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview().offset(8.0)
        }

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.bottom.equalTo(titleLabel.snp.top).offset(-8.0)
            make.centerX.equalToSuperview()
        }
    }

    func start() {
        activityIndicator.startAnimating()
    }

    func stop() {
        activityIndicator.stopAnimating()
    }
}
