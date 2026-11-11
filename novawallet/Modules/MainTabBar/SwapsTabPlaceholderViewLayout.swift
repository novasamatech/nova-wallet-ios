import UIKit
import SnapKit

final class SwapsTabPlaceholderViewLayout: UIView {
    let backgroundView = MultigradientView.background

    let titleLabel: UILabel = .create { view in
        view.apply(style: .boldTitle1Primary)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension SwapsTabPlaceholderViewLayout {
    func setupLayout() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(Constants.titleTopOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }
}

// MARK: Constants

private extension SwapsTabPlaceholderViewLayout {
    enum Constants {
        static let titleTopOffset: CGFloat = 11
    }
}
