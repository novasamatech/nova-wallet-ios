import UIKit
import SnapKit

final class DelegateInfoDetailsViewLayout: UIView {
    let descriptionView = MarkdownViewContainer(
        preferredWidth: UIScreen.main.bounds.width - 2 * UIConstants.horizontalInset
    )

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

    private func setupLayout() {
        addSubview(descriptionView)
        addSubview(activityIndicator)
        descriptionView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIConstants.horizontalInset)
        }
        activityIndicator.snp.makeConstraints {
            $0.edges.equalTo(descriptionView)
        }
    }
}
