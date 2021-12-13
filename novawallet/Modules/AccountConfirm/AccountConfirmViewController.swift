import UIKit
import SoraFoundation
import SoraUI
import AudioToolbox

final class AccountConfirmViewController: UIViewController, AdaptiveDesignable {
    typealias WordButton = ControlView<RoundedView, UILabel>

    private enum Constants {
        static let externalMargin: CGFloat = 16.0
        static let itemsSpacing: CGFloat = 8.0
        static let internalMargin: CGFloat = 16.0
        static let itemContentInsets = UIEdgeInsets(
            top: 6.0,
            left: 11.0,
            bottom: 8.0,
            right: 11.0
        )
        static let cornerRadius: CGFloat = 10.0
        static let buttonHeight: CGFloat = 32.0
    }

    private struct Layout {
        let leading: NSLayoutConstraint
        let top: NSLayoutConstraint
        let width: NSLayoutConstraint
        let height: NSLayoutConstraint
    }

    var presenter: AccountConfirmPresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var contentView: UIView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet private var bottomPlaneView: UIView!
    @IBOutlet private var topPlaneView: UIView!

    @IBOutlet private var buttonsView: UIView!
    @IBOutlet private var buttonsHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var nextButton: TriangularedButton!
    private var skipButton: TriangularedButton?

    @IBOutlet private var topPlaneHeight: NSLayoutConstraint!
    @IBOutlet private var bottomPlaneHeight: NSLayoutConstraint!

    private var minHeight: CGFloat = 0.0

    var wordTransitionAnimation = BlockViewAnimator(
        duration: 0.25,
        options: [.curveEaseOut]
    )

    var retryAnimation = TransitionAnimator(
        type: .fade,
        duration: 0.25
    )

    var wrongSequenceAnimation = ShakeAnimator(
        duration: 0.5,
        options: [.curveEaseInOut]
    )

    private var contentWidth: CGFloat = 0.0

    private var pendingButtons: [WordButton] = []
    private var pendingPlaceholders: [WordButton: ShapeView] = [:]
    private var submittedButtons: [WordButton] = []
    private var layouts: [WordButton: Layout] = [:]
    private var originalLayouts: [WordButton: Layout] = [:]
    private var wordsMapping: [WordButton: String] = [:]

    lazy var nextButtonTitle: LocalizableResource<String> = LocalizableResource { locale in
        R.string.localizable.commonNext(preferredLanguages: locale.rLanguages)
    }

    var skipButtonTitle: LocalizableResource<String>?

    override func viewDidLoad() {
        super.viewDidLoad()

        if skipButtonTitle != nil {
            createSkipButton()
        }

        setupNavigationItem()
        setupLocalization()
        configureLayout()

        nextButton.applyDefaultStyle()

        updateNextButton()

        presenter.setup()
    }

    private func configureLayout() {
        contentWidth = baseDesignSize.width * designScaleRatio.width - 2.0 * Constants.externalMargin
    }

    private func setupLocalization() {
        guard let locale = localizationManager?.selectedLocale else {
            return
        }

        titleLabel.text = R.string.localizable.confirmMnemonicTitle(preferredLanguages: locale.rLanguages)

        detailsLabel.text = R.string.localizable.confirmMnemonicSubtitle(
            preferredLanguages: locale.rLanguages
        )

        navigationItem.rightBarButtonItem?.title = R.string.localizable.commonReset(
            preferredLanguages: locale.rLanguages
        )

        nextButton.imageWithTitleView?.title = nextButtonTitle.value(for: locale)
        nextButton.invalidateLayout()

        skipButton?.imageWithTitleView?.title = skipButtonTitle?.value(for: locale)
    }

    private func createButton() -> WordButton {
        let button = WordButton(preferredHeight: Constants.buttonHeight)
        button.contentInsets = Constants.itemContentInsets
        button.translatesAutoresizingMaskIntoConstraints = false
        button.controlBackgroundView?.shadowOpacity = 0.0
        button.controlBackgroundView?.fillColor = .clear
        button.controlBackgroundView?.highlightedFillColor = .clear
        button.controlBackgroundView?.strokeColor = R.color.colorWhite24()!
        button.controlBackgroundView?.highlightedStrokeColor = R.color.colorWhite24()!
        button.controlBackgroundView?.strokeWidth = 1.0
        button.controlBackgroundView?.cornerRadius = Constants.cornerRadius
        button.changesContentOpacityWhenHighlighted = true

        button.addTarget(
            self,
            action: #selector(actionItem),
            for: .touchUpInside
        )

        return button
    }

    private func createIndexedWordAttributedString(for word: String, index: Int) -> NSAttributedString {
        let buttonTitleStr = NSMutableAttributedString(
            string: "\(index)",
            attributes: [
                .foregroundColor: R.color.colorWhite48()!,
                .font: UIFont.p2Paragraph
            ]
        )

        let wordAttributedStr = NSAttributedString(
            string: "  \(word)",
            attributes: [
                .foregroundColor: R.color.colorWhite()!,
                .font: UIFont.p2Paragraph
            ]
        )

        buttonTitleStr.append(wordAttributedStr)

        return buttonTitleStr
    }

    private func createWordAttributedString(for word: String) -> NSAttributedString {
        NSAttributedString(
            string: word,
            attributes: [
                .foregroundColor: R.color.colorWhite()!,
                .font: UIFont.p2Paragraph
            ]
        )
    }

    private func sizeForButton(_ button: WordButton) -> CGSize {
        let insets = button.contentInsets
        let contentSize = button.controlContentView.intrinsicContentSize
        return CGSize(
            width: contentSize.width + insets.left + insets.right,
            height: Constants.buttonHeight
        )
    }

    private func apply(words: [String]) {
        clearButtons()

        var newPendingButtons: [WordButton] = []

        for word in words {
            let button = createButton()
            button.controlContentView.attributedText = createWordAttributedString(for: word)

            newPendingButtons.append(button)
            wordsMapping[button] = word
        }

        newPendingButtons.forEach { contentView.addSubview($0) }

        pendingButtons = newPendingButtons

        let rows = createRowsFromButtons(pendingButtons)
        let (height, maxRowHeight) = layoutRows(rows, on: bottomPlaneView)
        minHeight = height + maxRowHeight + Constants.itemsSpacing + 2 * Constants.internalMargin

        layoutButtons()

        pendingPlaceholders = layoutPlaceholders()

        updateNextButton()
    }

    private func clearButtons() {
        pendingButtons.forEach { $0.removeFromSuperview() }
        pendingPlaceholders.values.forEach { $0.removeFromSuperview() }
        submittedButtons.forEach { $0.removeFromSuperview() }

        pendingButtons = []
        pendingPlaceholders = [:]
        submittedButtons = []
        layouts = [:]
        originalLayouts = [:]
        wordsMapping = [:]
    }

    private func setupNavigationItem() {
        let infoItem = UIBarButtonItem(
            title: nil,
            style: .plain,
            target: self,
            action: #selector(actionRetry)
        )
        navigationItem.rightBarButtonItem = infoItem
    }

    private func createSkipButton() {
        let skipButton = TriangularedButton()
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.applyAccessoryStyle()
        buttonsView.addSubview(skipButton)

        skipButton.addTarget(
            self,
            action: #selector(actionSkip),
            for: .touchUpInside
        )

        skipButton.leadingAnchor.constraint(equalTo: buttonsView.leadingAnchor).isActive = true
        skipButton.trailingAnchor.constraint(equalTo: buttonsView.trailingAnchor).isActive = true
        skipButton.bottomAnchor.constraint(
            equalTo: nextButton.topAnchor,
            constant: -UIConstants.mainAccessoryActionsSpacing
        ).isActive = true
        skipButton.heightAnchor.constraint(equalToConstant: UIConstants.actionHeight).isActive = true

        buttonsHeightConstraint.constant = 2.0 * UIConstants.actionHeight + UIConstants.mainAccessoryActionsSpacing

        self.skipButton = skipButton
    }

    private func updateNextButton() {
        let isEnabled = pendingButtons.isEmpty && !submittedButtons.isEmpty

        if isEnabled {
            nextButton.imageWithTitleView?.title = R.string.localizable.commonContinue(
                preferredLanguages: selectedLocale.rLanguages
            )

        } else {
            nextButton.imageWithTitleView?.title = R.string.localizable.confirmMnemonicSelectWord(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        nextButton.set(enabled: isEnabled)
    }

    @objc private func actionRetry() {
        presenter.requestWords()
    }

    @IBAction private func actionNext() {
        guard pendingButtons.isEmpty else {
            return
        }

        let words: [String] = submittedButtons.reduce(into: []) { list, button in
            if let title = wordsMapping[button] {
                list.append(title)
            }
        }

        presenter.confirm(words: words)
    }

    @objc private func actionSkip() {
        presenter.skip()
    }
}

extension AccountConfirmViewController {
    private func layoutButtons() {
        layoutPendingButtons()
        layoutSubmittedButtons()
    }

    private func layoutSubmittedButtons() {
        let rows = createRowsFromButtons(submittedButtons)
        let (height, _) = layoutRows(rows, on: topPlaneView)
        topPlaneHeight.constant = max(
            minHeight,
            height + 2.0 * Constants.internalMargin
        )
    }

    private func layoutPendingButtons() {
        let rows = createRowsFromButtons(pendingButtons)
        let (height, _) = layoutRows(rows, on: bottomPlaneView)
        bottomPlaneHeight.constant = max(minHeight, height + 2.0 * Constants.internalMargin)
    }

    private func createRowsFromButtons(_ buttons: [WordButton]) -> [[WordButton]] {
        let availableWidth = contentWidth - 2.0 * Constants.internalMargin

        var targetButtonIndex = 0

        var rows: [[WordButton]] = []

        var row: [WordButton] = []

        var remainedWidth = availableWidth

        while targetButtonIndex < buttons.count {
            let size = sizeForButton(buttons[targetButtonIndex])

            if size.width <= remainedWidth {
                row.append(buttons[targetButtonIndex])

                remainedWidth -= size.width + Constants.itemsSpacing

                targetButtonIndex += 1
            } else {
                if !row.isEmpty {
                    rows.append(row)
                    row = []
                } else {
                    break
                }

                remainedWidth = availableWidth
            }
        }

        if !row.isEmpty {
            rows.append(row)
        }

        return rows
    }

    private func layoutPlaceholders() -> [WordButton: ShapeView] {
        layouts.reduce(into: [WordButton: ShapeView]()) { result, item in
            let button = item.key
            let layout = item.value

            let shapeView = RoundedView()
            shapeView.translatesAutoresizingMaskIntoConstraints = false
            shapeView.alpha = 0.0

            let shapeLayer = shapeView.layer as? CAShapeLayer
            shapeLayer?.lineDashPattern = [5.0, 5.0]
            shapeLayer?.lineDashPhase = 0.0
            shapeView.fillColor = .clear
            shapeView.strokeWidth = 1.0
            shapeView.strokeColor = R.color.colorWhite16()!

            button.superview?.insertSubview(shapeView, belowSubview: button)

            shapeView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: layout.leading.constant
            ).isActive = true

            shapeView.topAnchor.constraint(
                equalTo: bottomPlaneView.topAnchor,
                constant: layout.top.constant
            ).isActive = true

            shapeView.widthAnchor.constraint(equalToConstant: layout.width.constant).isActive = true
            shapeView.heightAnchor.constraint(equalToConstant: layout.height.constant).isActive = true

            result[button] = shapeView
        }
    }

    private func layoutRows(_ rows: [[WordButton]], on plane: UIView) -> (CGFloat, CGFloat) {
        var currentY = Constants.internalMargin

        let availableWidth = contentWidth - 2.0 * Constants.internalMargin

        var totalHeight: CGFloat = 0.0
        var maxRowHeight: CGFloat = 0.0

        for row in rows {
            var width = row.reduce(CGFloat(0.0)) { result, item in
                result + sizeForButton(item).width
            }

            width += CGFloat(row.count - 1) * Constants.itemsSpacing

            let height = row.reduce(CGFloat(0.0)) { result, item in
                max(result, sizeForButton(item).height)
            }

            var originX = Constants.internalMargin + availableWidth / 2.0 - width / 2.0

            for item in row {
                let size = sizeForButton(item)

                if let layout = layouts[item] {
                    layout.leading.isActive = false
                    layout.top.isActive = false
                    layout.width.isActive = false
                    layout.height.isActive = false
                }

                let leading = item.leadingAnchor.constraint(
                    equalTo: contentView.leadingAnchor,
                    constant: originX
                )

                let itemY = currentY + height / 2.0 - size.height / 2.0
                let top = item.topAnchor.constraint(
                    equalTo: plane.topAnchor,
                    constant: itemY
                )

                let widthConstraint = item.widthAnchor.constraint(equalToConstant: size.width)
                let heghtConstraint = item.heightAnchor.constraint(equalToConstant: size.height)

                leading.isActive = true
                top.isActive = true
                widthConstraint.isActive = true
                heghtConstraint.isActive = true

                layouts[item] = Layout(
                    leading: leading,
                    top: top,
                    width: widthConstraint,
                    height: heghtConstraint
                )

                originX += size.width + Constants.itemsSpacing
            }

            currentY += height + Constants.itemsSpacing

            totalHeight += height
            maxRowHeight = max(maxRowHeight, height)
        }

        return (totalHeight + CGFloat(rows.count - 1) * Constants.itemsSpacing, maxRowHeight)
    }

    @IBAction private func actionTapOnSubmitView() {
        guard
            let button = submittedButtons.last,
            let word = wordsMapping[button] else {
            return
        }

        submittedButtons.removeLast()

        button.isUserInteractionEnabled = true
        pendingButtons.append(button)

        let placeholder = pendingPlaceholders[button]

        let currentLayout = layouts[button]
        layouts[button] = originalLayouts[button]

        let attributedTitle = createWordAttributedString(for: word)

        let animationBlock = {
            placeholder?.alpha = 0.0
            button.controlContentView.attributedText = attributedTitle
            currentLayout?.leading.isActive = false
            currentLayout?.top.isActive = false
            currentLayout?.width.isActive = false
            currentLayout?.height.isActive = false

            if let originalLayout = self.originalLayouts[button] {
                originalLayout.leading.isActive = true
                originalLayout.top.isActive = true
                originalLayout.width.isActive = true
                originalLayout.height.isActive = true
            }

            self.layoutSubmittedButtons()

            self.contentView.layoutIfNeeded()
        }

        wordTransitionAnimation.animate(
            block: animationBlock,
            completionBlock: nil
        )

        updateNextButton()
    }

    @objc private func actionItem(_ sender: AnyObject) {
        guard
            let button = sender as? WordButton,
            let word = wordsMapping[button],
            let index = pendingButtons.firstIndex(of: button) else {
            return
        }

        pendingButtons.remove(at: index)

        button.isUserInteractionEnabled = false
        submittedButtons.append(button)

        let placeholder = pendingPlaceholders[button]

        originalLayouts[button] = layouts[button]

        let attributedTitle = createIndexedWordAttributedString(
            for: word,
            index: submittedButtons.count
        )

        let animationBlock = {
            placeholder?.alpha = 1.0
            button.controlContentView.attributedText = attributedTitle
            self.layoutSubmittedButtons()

            self.contentView.layoutIfNeeded()
        }

        wordTransitionAnimation.animate(
            block: animationBlock,
            completionBlock: nil
        )

        updateNextButton()
    }
}

extension AccountConfirmViewController: AccountConfirmViewProtocol {
    func didReceive(words: [String], afterConfirmationFail: Bool) {
        if afterConfirmationFail {
            wrongSequenceAnimation.animate(view: contentView) { _ in
                self.apply(words: words)
                self.retryAnimation.animate(
                    view: self.contentView,
                    completionBlock: nil
                )
            }

            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        } else {
            apply(words: words)

            retryAnimation.animate(
                view: contentView,
                completionBlock: nil
            )
        }
    }
}

extension AccountConfirmViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
