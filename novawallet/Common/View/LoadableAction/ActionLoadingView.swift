import UIKit
import UIKit_iOS

final class ActionLoadingView: UIView {
    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorDimBackground()!
        view.cornerRadius = 12.0
        return view
    }()

    let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView()
        view.tintColor = R.color.colorIndicatorShimmering()
        view.hidesWhenStopped = true
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        activityIndicator.startAnimating()
    }

    func stop() {
        activityIndicator.stopAnimating()
    }

    private func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
