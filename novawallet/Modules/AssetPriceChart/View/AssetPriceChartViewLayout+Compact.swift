import UIKit
import UIKit_iOS

extension AssetPriceChartViewLayout {
    func setupCompactLayout() {
        clipsToBounds = true

        titleLabel.apply(style: .semiboldFootnotePrimary)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        priceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        priceChangeView.hidesIcon = true
        currentEntryDateLabel.apply(style: .footnoteSecondary)

        addSubview(compactHeaderView)
        addSubview(sparklineView)
        addSubview(chevronView)
        addSubview(chartView)
        addSubview(placeholderLabel)
        addSubview(expandControl)

        compactHeaderView.snp.makeConstraints { make in
            compactHeaderTopConstraint = make.top.equalToSuperview().offset(
                CompactConstants.collapsedHeaderTop
            ).constraint
            make.leading.equalToSuperview().inset(CompactConstants.horizontalInset)
            make.height.equalTo(CompactConstants.headerHeight)
            make.trailing.lessThanOrEqualTo(sparklineView.snp.leading).offset(-CompactConstants.headerSpacing)
        }

        chevronView.snp.makeConstraints { make in
            make.centerY.equalTo(compactHeaderView)
            make.trailing.equalToSuperview().inset(CompactConstants.chevronTrailing)
            make.size.equalTo(CompactConstants.chevronSize)
        }

        sparklineView.snp.makeConstraints { make in
            make.centerY.equalTo(compactHeaderView)
            make.trailing.equalTo(chevronView.snp.leading).offset(-CompactConstants.sparklineTrailing)
            make.size.equalTo(CompactConstants.sparklineSize)
        }

        chartView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(CompactConstants.chartTop)
            make.leading.trailing.equalToSuperview().inset(CompactConstants.horizontalInset)
            make.height.equalTo(CompactConstants.chartHeight)
        }

        expandControl.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(CompactConstants.collapsedHeight)
        }

        applyCompactExpansion(isExpanded: false, isExpandable: true, animated: false)
    }

    func applyCompactExpansion(isExpanded: Bool, isExpandable: Bool, animated: Bool) {
        isCompactExpanded = isExpanded

        compactHeaderTopConstraint?.update(
            offset: isExpanded ? CompactConstants.expandedHeaderTop : CompactConstants.collapsedHeaderTop
        )

        priceLabel.apply(style: isExpanded ? .semiboldSubhedlinePrimary : .footnoteSecondary)
        priceChangeView.detailsLabel.font = isExpanded ? .regularFootnote : .semiBoldFootnote

        chevronView.tintColor = isExpandable ? R.color.colorIconSecondary() : R.color.colorIconInactive()
        expandControl.isEnabled = isExpandable

        applyCompactContentVisibility()

        let transform = CGAffineTransform(
            rotationAngle: isExpanded ? -CGFloat.pi / 2 : CGFloat.pi / 2
        )

        if animated {
            UIView.animate(withDuration: CompactConstants.animationDuration) {
                self.chevronView.transform = transform
            }
        } else {
            chevronView.transform = transform
        }
    }

    func applyCompact(placeholder: String?) {
        compactPlaceholder = placeholder

        periodControl?.alpha = placeholder != nil ? CompactConstants.inactiveAlpha : 1
        periodControl?.isUserInteractionEnabled = placeholder == nil

        applyCompactContentVisibility()
    }

    func applyCompactHeader(showsEntryDate: Bool, showsChange: Bool) {
        priceChangeView.isHidden = showsEntryDate || !showsChange
        currentEntryDateLabel.isHidden = !showsEntryDate
    }

    func createCompactSkeletons(for spaceSize: CGSize) -> [any Skeletonable] {
        if isCompactExpanded {
            let lineWidth = CompactConstants.axisSkeletonSize.width
            let count = CompactConstants.chartYAxisLabelsCount

            return createSkeletons(
                for: spaceSize,
                lineWidths: Array(repeating: lineWidth, count: count),
                lineHeights: Array(repeating: CompactConstants.axisSkeletonSize.height, count: count),
                yOffsets: CompactConstants.axisSkeletonOffsets,
                xOffsets: Array(
                    repeating: spaceSize.width - CompactConstants.horizontalInset - lineWidth,
                    count: count
                )
            )
        } else {
            let size = CompactConstants.sparklineSkeletonSize
            let xOffset = spaceSize.width - CompactConstants.chevronTrailing - CompactConstants.chevronSize
                - CompactConstants.sparklineTrailing - CompactConstants.sparklineSize.width

            return createSkeletons(
                for: spaceSize,
                lineWidths: [size.width],
                lineHeights: [size.height],
                yOffsets: [CompactConstants.collapsedHeight / 2 - size.height / 2],
                xOffsets: [xOffset]
            )
        }
    }
}

// MARK: Private

private extension AssetPriceChartViewLayout {
    func applyCompactContentVisibility() {
        let hasPlaceholder = compactPlaceholder != nil

        compactHeaderView.isHidden = hasPlaceholder
        chartView.isHidden = hasPlaceholder
        sparklineView.isHidden = hasPlaceholder || isCompactExpanded
        placeholderLabel.isHidden = !hasPlaceholder

        guard let compactPlaceholder else { return }

        if isCompactExpanded {
            placeholderLabel.text = compactPlaceholder
            placeholderLabel.numberOfLines = 0
            placeholderLabel.adjustsFontSizeToFitWidth = false

            placeholderLabel.snp.remakeConstraints { make in
                make.centerY.equalTo(chartView)
                make.leading.trailing.equalToSuperview().inset(CompactConstants.horizontalInset)
            }
        } else {
            placeholderLabel.text = compactPlaceholder.replacingOccurrences(of: "\n", with: " ")
            placeholderLabel.numberOfLines = 1
            placeholderLabel.adjustsFontSizeToFitWidth = true
            placeholderLabel.minimumScaleFactor = CompactConstants.placeholderMinimumScale

            placeholderLabel.snp.remakeConstraints { make in
                make.centerY.equalTo(compactHeaderView)
                make.leading.equalToSuperview().inset(CompactConstants.horizontalInset)
                make.trailing.equalTo(chevronView.snp.leading).offset(-CompactConstants.headerSpacing)
            }
        }
    }
}

// MARK: Constants

extension AssetPriceChartViewLayout {
    enum CompactConstants {
        static let expandedHeight: CGFloat = 150
        static let collapsedHeight: CGFloat = 40
        static let horizontalInset: CGFloat = 12
        static let expandedHeaderTop: CGFloat = 12
        static let collapsedHeaderTop: CGFloat = 10
        static let headerHeight: CGFloat = 20
        static let headerSpacing: CGFloat = 6
        static let chevronTrailing: CGFloat = 16
        static let chevronSize: CGFloat = 16
        static let sparklineTrailing: CGFloat = 24
        static let sparklineSize = CGSize(width: 48, height: 20)
        static let chartTop: CGFloat = 40
        static let chartHeight: CGFloat = 64
        static let periodControlTopOffset: CGFloat = 6
        static let chartYAxisLabelsCount: Int = 3
        static let axisSkeletonSize = CGSize(width: 22, height: 6)
        static let axisSkeletonOffsets: [CGFloat] = [42, 21, 21]
        static let sparklineSkeletonSize = CGSize(width: 48, height: 6)
        static let inactiveAlpha: CGFloat = 0.4
        static let placeholderMinimumScale: CGFloat = 0.8
        static let animationDuration: TimeInterval = 0.25
    }
}
