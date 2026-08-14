import UIKit
import UIKit_iOS

final class LegalConsentViewLayout: UIView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .boldTitle3Primary)
        view.numberOfLines = 0
        view.textAlignment = .center
    }

    let subtitleLabel: UILabel = .create { view in
        view.apply(style: .regularSubhedlineSecondary)
        view.numberOfLines = 0
        view.textAlignment = .center
    }

    let consentView = LegalConsentView()

    let acceptButton: TriangularedButton = .create { view in
        view.applyDefaultStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBottomSheetBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Bind

extension LegalConsentViewLayout {
    func bind(viewModel: LegalConsentViewModel) {
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        consentView.bind(agreement: viewModel.agreement)
        acceptButton.imageWithTitleView?.title = viewModel.acceptTitle
        acceptButton.invalidateLayout()
    }

    func setAcceptEnabled(_ enabled: Bool) {
        if enabled {
            acceptButton.applyDefaultStyle()
        } else {
            acceptButton.applyDisabledStyle()
        }

        acceptButton.isUserInteractionEnabled = enabled
        acceptButton.invalidateLayout()
    }
}

// MARK: - Private

private extension LegalConsentViewLayout {
    func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(Constants.topInset)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
        }

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(Constants.titleToSubtitle)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
        }

        addSubview(consentView)
        consentView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(Constants.subtitleToConsent)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
        }

        addSubview(acceptButton)
        acceptButton.snp.makeConstraints { make in
            make.top.equalTo(consentView.snp.bottom).offset(Constants.consentToButton)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-UIConstants.actionBottomInset)
        }
    }
}

// MARK: - Constants

private extension LegalConsentViewLayout {
    enum Constants {
        static let topInset: CGFloat = 14.0
        static let horizontalInset: CGFloat = 20.0
        static let titleToSubtitle: CGFloat = 8.0
        static let subtitleToConsent: CGFloat = 28.0
        static let consentToButton: CGFloat = 24.0
    }
}
