import UIKit
import UIKit_iOS
import Foundation_iOS

class PinSetupViewController: UIViewController, AdaptiveDesignable, NavigationDependable {
    private enum Constants {
        static var cancelBottomMargin: CGFloat = 30.0
    }

    var presenter: PinSetupPresenterProtocol!
    var mode = PinView.Mode.create

    var cancellable: Bool = false

    var mainViewAccessibilityId: String? = "MainViewAccessibilityId"
    var bgViewAccessibilityId: String? = "BgViewAccessibilityId"
    var inputFieldAccessibilityId: String? = "InputFieldAccessibilityId"
    var keyPrefixAccessibilityId: String? = "KeyPrefixAccessibilityId"
    var backspaceAccessibilityId: String? = "BackspaceAccessibilityId"

    var localizableTopTitle: LocalizableResource<String> = LocalizableResource { _ in "" }

    weak var navigationControlling: NavigationControlling?

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var pinView: PinView!

    @IBOutlet private var navigationBar: UINavigationBar!

    @IBOutlet private var navigationBarTop: NSLayoutConstraint!
    @IBOutlet private var pinViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private var pinViewCenterConstraint: NSLayoutConstraint!

    private var cancelButton: UIButton?

    @IBOutlet var topLabel: UILabel!

    // MARK: View Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        configureNavigationBar()
        configurePinView()

        if cancellable {
            configureCancelButton()
        }

        setupLocalization()
        adjustLayoutConstraints()
        setupAccessibilityIdentifiers()

        presenter.start()
    }

    // MARK: Configure

    private func configureNavigationBar() {
        navigationBarTop.constant = UIApplication.shared.statusBarFrame.size.height

        navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationBar.shadowImage = UIImage()
        navigationBar.tintColor = R.color.colorTextPrimary()!
        navigationBar.delegate = self
    }

    private func configureCancelButton() {
        let cancelButton = UIButton()
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        let bottomMargin = -Constants.cancelBottomMargin * designScaleRatio.height

        cancelButton.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: bottomMargin
        ).isActive = true

        cancelButton.trailingAnchor.constraint(equalTo: pinView.trailingAnchor).isActive = true

        cancelButton.setTitleColor(R.color.colorIconPrimary()!, for: .normal)
        cancelButton.titleLabel?.font = UIFont.p1Paragraph

        cancelButton.addTarget(
            self,
            action: #selector(actionCancel),
            for: .touchUpInside
        )

        self.cancelButton = cancelButton
    }

    private func updateTitleLabelState() {
        let languages = localizationManager?.preferredLocalizations ?? []

        if pinView.mode == .create {
            if pinView.creationState == .normal {
                titleLabel.text = R.string(preferredLanguages: languages).localizable.pincodeSetYourPinCode()
            } else {
                titleLabel.text = R.string(preferredLanguages: languages).localizable.pincodeConfirmYourPinCode()
            }
        } else {
            titleLabel.text = R.string(preferredLanguages: languages).localizable.pincodeEnterPinCode()
        }
    }

    private func configurePinView() {
        pinView.mode = mode
        pinView.delegate = self

        pinView.numpadView?.accessoryIcon = pinView.numpadView?.accessoryIcon?.tinted(with: R.color.colorIconPrimary()!)
        pinView.numpadView?.backspaceIcon = pinView.numpadView?.backspaceIcon?.tinted(with: R.color.colorIconPrimary()!)

        let additionalButtonStyle = NumpadButtonStyle(
            fillColor: .clear,
            highlightedFillColor: R.color.colorCellBackgroundPressed()!
        )

        pinView.numpadView?.backspaceButtonStyle = additionalButtonStyle
        pinView.numpadView?.accessoryButtonStyle = additionalButtonStyle

        pinView.securedCharacterFieldsView?.style = SecuredCharacterFieldsView.Style(
            normalFillColor: R.color.colorIndicatorInactive()!,
            highlightedFillColor: R.color.colorIndicatorActive()!,
            normalStrokeColor: .clear,
            highlightedStrokeColor: .clear,
            strokeWidth: 0.0,
            fieldRadius: 6.0
        )
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        cancelButton?.setTitle(
            R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages),
            for: .normal
        )

        topLabel.text = localizableTopTitle.value(for: locale)

        updateTitleLabelState()
    }

    // MARK: Accessibility

    private func setupAccessibilityIdentifiers() {
        view.accessibilityIdentifier = mainViewAccessibilityId
        pinView.setupInputField(accessibilityId: inputFieldAccessibilityId)
        pinView.numpadView?.setupKeysAccessibilityIdWith(format: keyPrefixAccessibilityId)
        pinView.numpadView?.setupBackspace(accessibilityId: backspaceAccessibilityId)
    }

    // MARK: Layout

    private func adjustLayoutConstraints() {
        let designScaleRatio = self.designScaleRatio

        if isAdaptiveHeightDecreased || isAdaptiveWidthDecreased {
            let scale = min(designScaleRatio.width, designScaleRatio.height)

            if let numpadView = pinView.numpadView {
                pinView.numpadView?.keyRadius *= scale

                if let titleFont = numpadView.titleFont {
                    numpadView.titleFont = UIFont(name: titleFont.fontName, size: scale * titleFont.pointSize)
                }
            }

            if let currentFieldsView = pinView.characterFieldsView {
                let font = currentFieldsView.fieldFont

                if let newFont = UIFont(name: font.fontName, size: scale * font.pointSize) {
                    currentFieldsView.fieldFont = newFont
                }
            }

            pinView.securedCharacterFieldsView?.fieldRadius *= scale
        }

        if isAdaptiveHeightDecreased {
            pinView.verticalSpacing *= designScaleRatio.height

            if let cancelButton = cancelButton {
                pinView.verticalSpacing -= cancelButton.intrinsicContentSize.height
                pinViewCenterConstraint.constant -= cancelButton.intrinsicContentSize.height
            }

            pinView.numpadView?.verticalSpacing *= designScaleRatio.height
            pinView.characterFieldsView?.fieldSize.height *= designScaleRatio.height
            pinView.securedCharacterFieldsView?.fieldSize.height *= designScaleRatio.height
        }

        if isAdaptiveWidthDecreased {
            pinView.numpadView?.horizontalSpacing *= designScaleRatio.width
            pinView.characterFieldsView?.fieldSize.width *= designScaleRatio.width
            pinView.securedCharacterFieldsView?.fieldSize.width *= designScaleRatio.width
        }
    }

    // MARK: Action

    @objc func actionCancel() {
        presenter.cancel()
    }
}

extension PinSetupViewController: PinSetupViewProtocol {
    func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void) {
        var title: String?
        var message: String?

        let languages = localizationManager?.selectedLocale.rLanguages ?? []

        switch biometryType {
        case .touchId:
            title = R.string(preferredLanguages: languages).localizable.askTouchidTitle()
            message = R.string(preferredLanguages: languages).localizable.askTouchidMessage()
        case .faceId:
            title = R.string(preferredLanguages: languages).localizable.askFaceidTitle()
            message = R.string(preferredLanguages: languages).localizable.askFaceidMessage()
        case .none:
            completionBlock(true)
            return
        }

        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let useAction = UIAlertAction(
            title: R.string(preferredLanguages: languages).localizable.commonUse(),
            style: .default
        ) { (_: UIAlertAction) -> Void in
            completionBlock(true)
        }

        let skipAction = UIAlertAction(
            title: R.string(preferredLanguages: languages).localizable.commonSkip(),
            style: .cancel
        ) { (_: UIAlertAction) -> Void in
            completionBlock(false)
        }

        alertView.addAction(useAction)
        alertView.addAction(skipAction)

        present(alertView, animated: true, completion: nil)
    }

    func didReceiveWrongPincode() {
        if mode != .create {
            pinView?.reset(shouldAnimateError: true)
        }
    }

    func didChangeAccessoryState(enabled: Bool, availableBiometryType: AvailableBiometryType) {
        pinView?.numpadView?.supportsAccessoryControl = enabled
        pinView?.numpadView?.accessoryIcon = availableBiometryType.accessoryIcon?.tinted(
            with: R.color.colorTextPrimary()!
        )
    }
}

extension PinSetupViewController: PinViewDelegate {
    func didFailConfirmation(pinView _: PinView) {}

    func didCompleteInput(pinView _: PinView, result: String) {
        presenter.submit(pin: result)
    }

    func didChange(pinView: PinView, from _: PinView.CreationState) {
        updateTitleLabelState()

        let shouldAnimate = navigationControlling == nil
        if pinView.creationState == .confirm {
            navigationControlling?.setNavigationBarHidden(true, animated: false)
            navigationBar.pushItem(UINavigationItem(), animated: shouldAnimate)
        } else {
            navigationControlling?.setNavigationBarHidden(false, animated: false)
            navigationBar.popItem(animated: shouldAnimate)
        }
    }

    func didSelectAccessoryControl(pinView _: PinView) {
        presenter.activateBiometricAuth()
    }
}

extension PinSetupViewController: UINavigationBarDelegate {
    func navigationBar(_: UINavigationBar, shouldPop _: UINavigationItem) -> Bool {
        if pinView.creationState == .confirm {
            navigationControlling?.setNavigationBarHidden(false, animated: false)
        }

        pinView.resetCreationState(animated: true)
        updateTitleLabelState()
        return true
    }
}

extension PinSetupViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
