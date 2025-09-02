import UIKit
import UIKit_iOS

class RoundedSegmentedControl: UIControl {
    private enum Constants {
        static let selectionAnimationKey = "selectionAnimationKey"
    }

    var titles: [String] = ["Segment1", "Segment2"] {
        didSet {
            if oldValue.count != titles.count {
                _selectedSegmentIndex = titles.count > 0 ? 0 : -1
            }

            clearSegments()
            buildSegments()

            setNeedsLayout()
        }
    }

    var selectedSegmentIndex: Int {
        get {
            _selectedSegmentIndex
        }

        set {
            _selectedSegmentIndex = newValue
            updateSelectionLayerFrame()
            updateSegmentsSelection()
        }
    }

    var numberOfSegments: Int {
        titles.count
    }

    var titleColor: UIColor = .black {
        didSet {
            updateSegmentsSelection()
        }
    }

    var selectedTitleColor: UIColor = .white {
        didSet {
            if _selectedSegmentIndex >= 0 {
                segments[_selectedSegmentIndex].textColor = selectedTitleColor
            }
        }
    }

    var titleFont: UIFont? {
        didSet {
            segments.forEach { $0.font = titleFont }
        }
    }

    var selectionColor: UIColor = .white {
        didSet {
            applySelectionColor()
        }
    }

    var selectionCornerRadius: CGFloat = 10.0 {
        didSet {
            applySelectionPath()
        }
    }

    var contentInsets: UIEdgeInsets = .init(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)

    var selectionAnimationDuration: TimeInterval = 0.2

    var selectionTimingOption: CAMediaTimingFunctionName = .linear

    var layoutStrategy: ListViewLayoutStrategyProtocol = HorizontalEqualWidthLayoutStrategy() {
        didSet {
            setNeedsLayout()
        }
    }

    let backgroundView: RoundedView = {
        let view = RoundedView()
        view.shadowOpacity = 0
        view.fillColor = .gray
        view.cornerRadius = 12.0
        view.isUserInteractionEnabled = false
        return view
    }()

    private var _selectedSegmentIndex: Int = 0
    private var segments: [UILabel] = []
    private var selectionLayer = CAShapeLayer()

    private var selectionContentSize: CGSize {
        CGSize(
            width: max(bounds.width - contentInsets.left - contentInsets.right, 0),
            height: max(bounds.height - contentInsets.top - contentInsets.bottom, 0)
        )
    }

    private var selectedTitleLabel: UILabel? {
        selectedSegmentIndex >= 0 ? segments[selectedSegmentIndex] : nil
    }

    // MARK: Overriden initializers

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    private func configure() {
        backgroundColor = UIColor.clear

        addSubview(backgroundView)

        buildSegments()
        configureSelectionLayer()
    }

    private func configureSelectionLayer() {
        layer.addSublayer(selectionLayer)

        applySelectionColor()
        applySelectionPath()
        updateSelectionLayerFrame()
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundView.frame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height)

        let contentFrame = CGRect(
            x: contentInsets.left,
            y: contentInsets.top,
            width: bounds.width - contentInsets.left - contentInsets.right,
            height: bounds.height - contentInsets.top - contentInsets.bottom
        )

        layoutStrategy.layout(views: segments, in: contentFrame)

        applySelectionPath()
        updateSelectionLayerFrame()
    }

    // MARK: Segments Management

    private func buildSegments() {
        guard !titles.isEmpty else {
            return
        }

        for (index, title) in titles.enumerated() {
            let segmentLabel = UILabel()
            segmentLabel.backgroundColor = .clear
            segmentLabel.textAlignment = .center
            segmentLabel.text = title
            addSubview(segmentLabel)

            applyStyle(for: segmentLabel, at: index)

            segments.append(segmentLabel)
        }
    }

    private func clearSegments() {
        segments.forEach { $0.removeFromSuperview() }
        segments.removeAll()
    }

    private func applyStyle(for segmentLabel: UILabel, at index: Int) {
        segmentLabel.textColor = index == _selectedSegmentIndex ? selectedTitleColor : titleColor
        segmentLabel.font = titleFont
    }

    // MARK: Selection Management

    private func applySelectionColor() {
        selectionLayer.fillColor = selectionColor.cgColor
    }

    private func applySelectionPath() {
        guard let width = selectedTitleLabel?.frame.size.width else {
            return
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: selectionContentSize.height)
        let selectionPath = UIBezierPath(roundedRect: rect, cornerRadius: selectionCornerRadius)

        selectionLayer.path = selectionPath.cgPath
    }

    private func updateSelectionLayerFrame() {
        guard let titleLabel = selectedTitleLabel else {
            return
        }

        selectionLayer.frame = CGRect(
            x: titleLabel.frame.origin.x,
            y: contentInsets.top,
            width: titleLabel.frame.size.width,
            height: selectionContentSize.height
        )
    }

    private func updateSegmentsSelection() {
        for (index, label) in segments.enumerated() {
            label.textColor = index == _selectedSegmentIndex ? selectedTitleColor : titleColor
        }
    }

    private func animateSelectionIndexChange(_ fromIndex: Int) {
        selectionLayer.removeAnimation(forKey: Constants.selectionAnimationKey)

        let previousLabel = segments[fromIndex]

        guard let titleLabel = selectedTitleLabel else {
            return
        }

        let oldFrame = CGRect(
            x: previousLabel.frame.origin.x,
            y: contentInsets.top,
            width: previousLabel.frame.size.width,
            height: selectionContentSize.height
        )

        let newFrame = CGRect(
            x: titleLabel.frame.origin.x,
            y: contentInsets.top,
            width: titleLabel.frame.size.width,
            height: selectionContentSize.height
        )

        let animation = CABasicAnimation(keyPath: "frame")
        animation.fromValue = oldFrame
        animation.toValue = newFrame
        animation.duration = selectionAnimationDuration
        animation.timingFunction = CAMediaTimingFunction(name: selectionTimingOption)

        selectionLayer.frame = newFrame

        selectionLayer.add(animation, forKey: Constants.selectionAnimationKey)
    }

    // MARK: Action Handlers

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let shouldBeginTracking = super.beginTracking(touch, with: event)

        guard case .began = touch.phase else {
            return shouldBeginTracking
        }

        let location = touch.location(in: self)

        guard
            let newIndex = segments.firstIndex(where: { $0.frame.contains(location) }),
            selectedSegmentIndex != newIndex else {
            return shouldBeginTracking
        }

        let oldIndex = _selectedSegmentIndex
        _selectedSegmentIndex = newIndex

        animateSelectionIndexChange(oldIndex)
        updateSegmentsSelection()

        sendActions(for: .valueChanged)

        return shouldBeginTracking
    }
}
