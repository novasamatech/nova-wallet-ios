import UIKit
import SnapKit
import UIKit_iOS

final class TransactionHistoryViewLayout: UIView {
    private(set) var titleLeft: Constraint?
    private(set) var headerTop: Constraint?
    private(set) var headerHeight: Constraint?

    let backgroundView: WalletHistoryBackgroundView = {
        let backgroundView = WalletHistoryBackgroundView()
        let cornerCut: UIRectCorner = [.topLeft, .topRight]
        backgroundView.fullBackgroundView.cornerCut = cornerCut
        backgroundView.minimizedBackgroundView.cornerCut = cornerCut
        return backgroundView
    }()

    let closeIcon = R.image.iconClose()?.tinted(with: R.color.colorIconPrimary()!)
    let filterIcon = R.image.iconFilter()?.tinted(with: R.color.colorIconPrimary()!)

    lazy var filterButton: RoundedButton = .create {
        $0.applyIconStyle()
        $0.imageWithTitleView?.iconImage = filterIcon
    }

    lazy var closeButton: RoundedButton = .create {
        $0.applyIconStyle()
        $0.imageWithTitleView?.iconImage = closeIcon
    }

    let pageLoadingView: PageLoadingView = .create {
        $0.verticalMargin = Constants.loadingViewMargin
        let size = $0.intrinsicContentSize
        $0.frame = CGRect(origin: .zero, size: size)
        $0.activityIndicatorView.color = R.color.colorIconSecondary()!
    }

    lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = .init(top: 0, left: 0, bottom: 16, right: 0)
        view.tableFooterView = pageLoadingView
        view.isScrollEnabled = true
        return view
    }()

    let titleLabel = UILabel(style: .init(
        textColor: R.color.colorTextPrimary()!,
        font: .semiBoldSubheadline
    ))
    let headerView: UIView = .create {
        $0.backgroundColor = .clear
    }

    let contentView: UIView = .create {
        $0.backgroundColor = .clear
    }

    let panIndicatorView: RoundedView = .create {
        $0.cornerRadius = 2.5
        $0.fillColor = R.color.colorPullIndicator()!
        $0.shadowOpacity = 0
    }

    init(frame: CGRect, supportsFilters: Bool) {
        super.init(frame: frame)

        setupLayout(supportingFilters: supportsFilters)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout(supportingFilters: Bool) {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(headerView)
        headerView.snp.makeConstraints {
            headerHeight = $0.height.equalTo(42).constraint
            headerTop = $0.top.equalToSuperview().offset(16).constraint
            $0.leading.trailing.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.trailing.leading.bottom.equalToSuperview()
            $0.top.equalTo(headerView.snp.bottom)
        }

        addSubview(panIndicatorView)
        panIndicatorView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(5)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(35)
            $0.height.equalTo(5)
        }

        if supportingFilters {
            headerView.addSubview(filterButton)
            filterButton.snp.makeConstraints {
                $0.trailing.equalToSuperview().inset(10)
                $0.width.height.equalTo(44)
                $0.centerY.equalToSuperview()
            }
        }

        headerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            titleLeft = $0.leading.equalToSuperview().inset(Constants.titleLeftCompactInset).constraint
            $0.centerY.equalToSuperview()
        }

        headerView.addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(10)
            $0.width.height.equalTo(44)
            $0.centerY.equalToSuperview()
        }

        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.trailing.leading.bottom.equalToSuperview()
            $0.top.equalTo(headerView.snp.bottom)
        }
    }
}

extension TransactionHistoryViewLayout {
    enum Constants {
        static let loadingViewMargin: CGFloat = 4.0
        static let cornerRadius: CGFloat = 12
        static let titleLeftCompactInset: CGFloat = 20
    }
}
