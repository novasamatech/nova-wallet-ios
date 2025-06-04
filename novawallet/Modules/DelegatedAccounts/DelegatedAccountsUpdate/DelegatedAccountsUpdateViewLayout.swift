import UIKit

final class DelegatedAccountsUpdateViewLayout: UIView {
    let titleLabel: UILabel = .create {
        $0.apply(style: .bottomSheetTitle)
        $0.numberOfLines = 0
    }

    var segmentedControl: RoundedSegmentedControl = .create { view in
        view.backgroundView.fillColor = R.color.colorSegmentedBackground()!
        view.selectionColor = R.color.colorSegmentedTabActive()!
        view.titleFont = .regularFootnote
        view.selectedTitleColor = R.color.colorTextPrimary()!
        view.titleColor = R.color.colorTextSecondary()!
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
        view.registerClassForCell(ProxyInfoTableViewCell.self)
        view.registerHeaderFooterView(withClass: SectionTextHeaderView.self)
        return view
    }()

    let doneButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    // Container for sticky behavior
    private let stickyContainer: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBottomSheetBackground()
        return view
    }()

    // Header view that will be added to table view
    private let tableHeaderView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private var isSegmentedControlSticky = false
    private var originalSegmentedControlFrame: CGRect = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBottomSheetBackground()
        setupLayout()
        setupTableView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        // Add main components
        addSubview(titleLabel)
        addSubview(stickyContainer)
        addSubview(tableView)
        addSubview(doneButton)

        // Add segmented control to sticky container
        stickyContainer.addSubview(segmentedControl)

        // Title label constraints
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Constants.titleTopOffset)
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        // Sticky container constraints (initially below title)
        stickyContainer.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Constants.segmentedControlTopOffset)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(Constants.segmentedControlHeight)
        }

        // Segmented control constraints within sticky container
        segmentedControl.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            $0.height.equalTo(Constants.segmentedControlInnerHeight)
        }

        // Table view constraints (starts below segmented control)
        tableView.snp.makeConstraints {
            $0.top.equalTo(stickyContainer.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(doneButton.snp.top)
        }

        // Done button constraints
        doneButton.snp.makeConstraints {
            $0.height.equalTo(UIConstants.actionHeight)
            $0.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            $0.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }
    }

    private func setupTableView() {
        // Create a header view that provides space for the segmented control
        // when it's in sticky mode
        tableHeaderView.frame = CGRect(x: 0, y: 0, width: 0, height: Constants.tableHeaderHeight)
        tableView.tableHeaderView = tableHeaderView

        // Set up scroll view delegate to handle sticky behavior
        tableView.delegate = self
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Store the original frame for calculations
        if originalSegmentedControlFrame == .zero {
            originalSegmentedControlFrame = stickyContainer.frame
        }
    }

    private func updateStickyBehavior() {
        let scrollOffset = tableView.contentOffset.y
        let headerHeight = Constants.tableHeaderHeight

        // Calculate when segmented control should become sticky
        // This happens when the user scrolls past the header area
        let shouldBeSticky = scrollOffset > -headerHeight

        if shouldBeSticky != isSegmentedControlSticky {
            isSegmentedControlSticky = shouldBeSticky
            updateStickyConstraints()
        }
    }

    private func updateStickyConstraints() {
        if isSegmentedControlSticky {
            // Make segmented control stick to safe area top
            stickyContainer.snp.remakeConstraints {
                $0.top.equalTo(safeAreaLayoutGuide.snp.top)
                $0.leading.trailing.equalToSuperview()
                $0.height.equalTo(Constants.segmentedControlHeight)
            }

            // Add shadow to indicate sticky state
            stickyContainer.layer.shadowColor = UIColor.black.cgColor
            stickyContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
            stickyContainer.layer.shadowRadius = 4
            stickyContainer.layer.shadowOpacity = 0.1

            // Adjust table view top constraint to account for sticky segmented control
            tableView.snp.remakeConstraints {
                $0.top.equalTo(stickyContainer.snp.bottom)
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalTo(doneButton.snp.top)
            }

        } else {
            // Return to normal position
            stickyContainer.snp.remakeConstraints {
                $0.top.equalTo(titleLabel.snp.bottom).offset(Constants.segmentedControlTopOffset)
                $0.leading.trailing.equalToSuperview()
                $0.height.equalTo(Constants.segmentedControlHeight)
            }

            // Remove shadow
            stickyContainer.layer.shadowOpacity = 0

            // Return table view to original position
            tableView.snp.remakeConstraints {
                $0.top.equalTo(stickyContainer.snp.bottom)
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalTo(doneButton.snp.top)
            }
        }

        UIView.animate(withDuration: 0.2) {
            self.layoutIfNeeded()
        }
    }
}

// MARK: - UITableViewDelegate

extension DelegatedAccountsUpdateViewLayout: UITableViewDelegate {
    func scrollViewDidScroll(_: UIScrollView) {
        updateStickyBehavior()
    }

    func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        // This will be implemented by the view controller
        UITableView.automaticDimension
    }
}

// MARK: - Constants

extension DelegatedAccountsUpdateViewLayout {
    enum Constants {
        static let titleTopOffset: CGFloat = 16
        static let segmentedControlTopOffset: CGFloat = 20
        static let segmentedControlHeight: CGFloat = 56
        static let segmentedControlInnerHeight: CGFloat = 32
        static let tableHeaderHeight: CGFloat = 8 // Small space for the table header
    }
}
