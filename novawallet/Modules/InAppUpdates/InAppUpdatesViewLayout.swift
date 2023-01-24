import UIKit

final class InAppUpdatesViewLayout: UIView {
    let gradientBannerView: GradientBannerView = .create {
        $0.infoView.imageView.image = R.image.iconBannerCriticalUpdate()
        $0.stackView.setCustomSpacing(8, after: $0.infoView)
        $0.bind(model: .criticalUpdate())
    }

    let tableView: UITableView = .create {
        $0.separatorStyle = .none
        $0.backgroundColor = .clear
        $0.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        $0.registerClassForCell(VersionTableViewCell.self)
        $0.rowHeight = UITableView.automaticDimension
    }

    let installButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(gradientBannerView)
        gradientBannerView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top).offset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(gradientBannerView.snp.bottom).offset(16)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        addSubview(installButton)
        installButton.snp.makeConstraints {
            $0.top.equalTo(tableView.snp.bottom)
            $0.height.equalTo(52)
            $0.leading.trailing.equalToSuperview().inset(18)
            $0.bottom.equalTo(safeAreaLayoutGuide)
        }
    }

    func setBannerState(isCritical: Bool, locale _: Locale) {
        if isCritical {
            gradientBannerView.infoView.imageView.image = R.image.iconBannerCriticalUpdate()
            gradientBannerView.bind(model: .criticalUpdate())
            gradientBannerView.infoView.titleLabel.text = "Critical update"
            gradientBannerView.infoView.subtitleLabel.text = "To avoid any issues, and improve your user experience, we strongly recommend that you install recent updates as soon as possible"
        } else {
            gradientBannerView.infoView.imageView.image = R.image.iconBannerMajorUpdate()
            gradientBannerView.bind(model: .majorUpdate())
            gradientBannerView.infoView.titleLabel.text = "Major update"
            gradientBannerView.infoView.subtitleLabel.text = "Lots of amazing new features are available for Nova Wallet with the recent updates! Make sure to update your application to access them!"
        }
    }
}
