import UIKit
import UIKit_iOS
import SnapKit

final class AccountManagementHeaderView: UIView {
    let textBackgroundView: TriangularedView = {
        let view = TriangularedView()
        view.sideLength = 10.0
        view.shadowOpacity = 0.0
        view.fillColor = .clear
        view.highlightedFillColor = .clear
        view.strokeWidth = 1.0
        view.strokeColor = R.color.colorCheckboxBorder()!
        view.highlightedStrokeColor = R.color.colorCheckboxBorder()!
        return view
    }()

    let textField: AnimatedTextField = {
        let field = AnimatedTextField()
        field.contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 6.0, right: 16.0)
        field.titleColor = R.color.colorTextSecondary()!
        field.titleFont = .caption1
        field.textColor = R.color.colorTextPrimary()
        field.textFont = .regularSubheadline
        field.placeholderColor = R.color.colorTextSecondary()!
        field.placeholderFont = .regularSubheadline
        field.cursorColor = R.color.colorTextPrimary()!
        return field
    }()

    private(set) var hintView: AccountManagementHintView?

    private(set) var bannerView: LedgerMigrationBannerView?

    var bottomInset: CGFloat = 0.0 {
        didSet {
            if let hintView = hintView {
                hintView.snp.updateConstraints { make in
                    make.bottom.equalToSuperview().inset(bottomInset)
                }
            }
        }
    }

    private var messageType: AccountManageWalletViewModel.MessageType = .none {
        didSet {
            switch messageType {
            case .hint:
                clearBannerView()
                setupHintView()
            case .banner:
                clearHintView()
                setupBannerView()
            case .none:
                clearHintView()
                clearBannerView()
            }

            updateFieldConstraints()
        }
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

    func bind(viewModel: AccountManageWalletViewModel, locale _: Locale = Locale.current) {
        messageType = viewModel.messageType

        switch viewModel.messageType {
        case let .hint(text, icon):
            hintView?.bindHint(text: text, icon: icon)

            guard let context = viewModel.context else { return }

            hintView?.bindDelegatedWalletContext(context)
        case let .banner(bannerViewModel):
            bannerView?.bind(viewModel: bannerViewModel)
        case .none:
            break
        }
    }

    func apply(bannerStyle: LedgerMigrationBannerView.Style) {
        bannerView?.apply(style: bannerStyle)
    }

    private func setupHintView() {
        guard hintView == nil else {
            return
        }

        let view = AccountManagementHintView()
        addSubview(view)

        view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.bottom.equalToSuperview().inset(bottomInset)
        }

        hintView = view
    }

    private func clearHintView() {
        hintView?.removeFromSuperview()
        hintView = nil
    }

    private func setupBannerView() {
        guard bannerView == nil else {
            return
        }

        let view = LedgerMigrationBannerView()
        addSubview(view)

        view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.bottom.equalToSuperview().inset(bottomInset)
        }

        bannerView = view
    }

    private func clearBannerView() {
        bannerView?.removeFromSuperview()
        bannerView = nil
    }

    private func applyFieldConstraints(for make: ConstraintMaker) {
        make.top.equalToSuperview().inset(10.0)
        make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        make.height.equalTo(52.0)

        if let hintView {
            make.bottom.equalTo(hintView.snp.top).offset(-16.0)
        } else if let bannerView {
            make.bottom.equalTo(bannerView.snp.top).offset(-16.0)
        } else {
            make.bottom.equalToSuperview().inset(textBackgroundView.strokeWidth)
        }
    }

    private func updateFieldConstraints() {
        textBackgroundView.snp.remakeConstraints { make in
            applyFieldConstraints(for: make)
        }
    }

    func setupLayout() {
        addSubview(textBackgroundView)
        textBackgroundView.snp.makeConstraints { make in
            applyFieldConstraints(for: make)
        }

        textBackgroundView.addSubview(textField)
        textField.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(textBackgroundView.strokeWidth)
        }
    }
}
