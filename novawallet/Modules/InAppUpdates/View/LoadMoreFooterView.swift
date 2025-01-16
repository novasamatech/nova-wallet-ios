import UIKit_iOS
import UIKit

final class LoadMoreFooterView: UIView {
    let moreButton: RoundedButton = .create { button in
        button.applyIconStyle()
        let color = R.color.colorButtonTextAccent()!
        button.imageWithTitleView?.titleColor = color
        button.imageWithTitleView?.titleFont = .regularFootnote
        button.contentInsets = .zero
    }

    let activityIndicator: UIActivityIndicatorView = .create {
        $0.hidesWhenStopped = true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        .init(width: UIView.noIntrinsicMetric, height: 34)
    }

    func setupLayout() {
        addSubview(moreButton)
        addSubview(activityIndicator)
        moreButton.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        activityIndicator.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
    }

    func bind(text: LoadableViewModelState<String>) {
        switch text {
        case .loading:
            moreButton.imageWithTitleView?.title = ""
            activityIndicator.startAnimating()
        case let .loaded(value), let .cached(value):
            activityIndicator.stopAnimating()
            moreButton.imageWithTitleView?.title = value
        }
    }
}
