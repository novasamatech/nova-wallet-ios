import SoraUI
import UIKit

final class LoadMoreFooterView: UITableViewHeaderFooterView {
    let moreButton: RoundedButton = .create { button in
        button.applyIconStyle()
        let color = R.color.colorButtonTextAccent()!
        button.imageWithTitleView?.titleColor = color
        button.imageWithTitleView?.titleFont = .regularFootnote
    }

    let activityIndicator: UIActivityIndicatorView = .create {
        $0.hidesWhenStopped = true
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        contentView.addSubview(moreButton)
        contentView.addSubview(activityIndicator)
        moreButton.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(8)
            $0.centerX.equalToSuperview()
        }
        activityIndicator.snp.makeConstraints {
            $0.edges.equalTo(moreButton)
        }
    }

    func bind(text: LoadableViewModelState<String>) {
        switch text {
        case .loading:
            activityIndicator.startAnimating()
        case let .loaded(value), let .cached(value):
            activityIndicator.stopAnimating()
            moreButton.imageWithTitleView?.title = value
        }
    }
}
