import UIKit
import SnapKit

final class DelegatedAccountsUpdateViewLayout: UIView {
    let titleLabel: UILabel = .create {
        $0.apply(style: .bottomSheetTitle)
        $0.numberOfLines = 0
    }

    let infoView = ProxyInfoView()

    var segmentedControl: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = R.color.colorSegmentedBackground()!
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularSubheadline
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
        view.backgroundView.cornerRadius = 12
    }

    lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .grouped)
        view.separatorStyle = .none
        view.backgroundColor = .clear
        view.contentInset = .zero
        view.rowHeight = UITableView.automaticDimension
        view.allowsSelection = false
        view.showsVerticalScrollIndicator = false
        view.contentInsetAdjustmentBehavior = .never
        view.tableHeaderView = .init(frame: .init(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        view.sectionHeaderHeight = 0
        view.sectionFooterHeight = 0
        view.registerClassForCell(ProxyTableViewCell.self)
        view.registerHeaderFooterView(withClass: SectionTextHeaderView.self)
        view.contentInsetAdjustmentBehavior = .never
        view.contentInset = .init(
            top: Constants.tableViewContentInset,
            left: .zero,
            bottom: .zero,
            right: .zero
        )
        return view
    }()

    let doneButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    let nonScrollableContainer: UIView = .create {
        $0.backgroundColor = R.color.colorBottomSheetBackground()
    }

    let clippingContainer: UIView = .create {
        $0.clipsToBounds = true
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

    private func setupLayout() {
        addSubview(clippingContainer)

        clippingContainer.addSubview(tableView)
        clippingContainer.addSubview(doneButton)
        clippingContainer.addSubview(nonScrollableContainer)

        nonScrollableContainer.addSubview(segmentedControl)
        nonScrollableContainer.addSubview(titleLabel)
        nonScrollableContainer.addSubview(infoView)

        clippingContainer.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        nonScrollableContainer.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.top.equalToSuperview().inset(0.0)
        }

        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Constants.titleTopOffset)
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        infoView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Constants.titleToInfoSpacing)
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        segmentedControl.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            $0.top.equalTo(infoView.snp.bottom).offset(Constants.infoToSegmentedSpacing)
            $0.bottom.equalToSuperview()
            $0.height.equalTo(Constants.segmentedControlHeight)
        }

        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(doneButton.snp.top).offset(-Constants.tableViewBottomOffset)
        }

        doneButton.snp.makeConstraints {
            $0.height.equalTo(Constants.doneButtonHeight)
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            $0.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.doneButtonBottomOffset)
        }
    }

    func calculateTopContentBehavior(with scrollViewOffset: CGFloat) -> TopContentBehavior {
        let containerInitialBottomY = nonScrollableContainer.bounds.height

        guard scrollViewOffset <= containerInitialBottomY else {
            return .fixed
        }

        let topContentOffsetValue = containerInitialBottomY - scrollViewOffset

        let maxY = containerInitialBottomY - Constants.segmentedControlHeight
        let canMoveContent = (topContentOffsetValue <= maxY)

        if canMoveContent {
            return .moving(minY: topContentOffsetValue)
        } else {
            return .fixed
        }
    }

    func updateStickyContent(with scrollViewOffset: CGFloat) {
        let realOffset = -scrollViewOffset

        let topContentBehavior = calculateTopContentBehavior(with: realOffset)

        switch topContentBehavior {
        case let .moving(minY):
            nonScrollableContainer.snp.updateConstraints {
                $0.top.equalToSuperview().inset(-minY)
            }
        case .fixed:
            return
        }
    }
}

// MARK: - Constants

extension DelegatedAccountsUpdateViewLayout {
    enum Constants {
        static let titleTopOffset: CGFloat = 10
        static let titleToInfoSpacing: CGFloat = 10
        static let infoToSegmentedSpacing: CGFloat = 16
        static let segmentToListSpacing: CGFloat = 8
        static let infoHeight: CGFloat = 94
        static let titleHeight: CGFloat = 22
        static let segmentedControlHeight: CGFloat = 40
        static let tableViewBottomOffset: CGFloat = 16
        static let doneButtonHeight: CGFloat = 52
        static let doneButtonBottomOffset: CGFloat = 16
        static let tableViewContentInset: CGFloat = 165
    }
}

extension DelegatedAccountsUpdateViewLayout {
    enum TopContentBehavior {
        case fixed
        case moving(minY: CGFloat)
    }
}
