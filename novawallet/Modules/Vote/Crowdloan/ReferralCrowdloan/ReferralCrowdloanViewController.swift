import UIKit
import Foundation_iOS
import UIKit_iOS

final class ReferralCrowdloanViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferralCrowdloanViewLayout

    let presenter: ReferralCrowdloanPresenterProtocol

    private var referralViewModel: ReferralCrowdloanViewModel?
    private var codeInputViewModel: InputViewModelProtocol?

    init(presenter: ReferralCrowdloanPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferralCrowdloanViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()

        presenter.setup()
    }

    private func configure() {
        rootView.codeInputView.animatedInputField.textField.returnKeyType = .done
        rootView.codeInputView.animatedInputField.textField.autocapitalizationType = .none
        rootView.codeInputView.animatedInputField.textField.autocorrectionType = .no
        rootView.codeInputView.animatedInputField.textField.spellCheckingType = .no

        rootView.codeInputView.animatedInputField.delegate = self
        rootView.codeInputView.animatedInputField.addTarget(
            self, action: #selector(actionCodeChanged(_:)),
            for: .editingChanged
        )

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(actionTapTerms(_:)))
        rootView.termsLabel.addGestureRecognizer(tapGestureRecognizer)

        rootView.termsSwitchView.addTarget(self, action: #selector(actionSwitchTerms), for: .valueChanged)

        rootView.actionButton.addTarget(self, action: #selector(actionApplyInputCode), for: .touchUpInside)
        rootView.applyAppBonusButton.addTarget(self, action: #selector(actionApplyDefaultCode), for: .touchUpInside)

        rootView.learnMoreView.addTarget(self, action: #selector(actionLearnMore), for: .touchUpInside)
    }

    private func setupLocalization() {
        title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonBonus()

        rootView.locale = selectedLocale

        applyReferralViewModel()
    }

    private func applyReferralViewModel() {
        guard let referralViewModel = referralViewModel else {
            return
        }

        rootView.applyAppBonusLabel.text = R.string(
            preferredLanguages: selectedLocale.rLanguages
        ).localizable.crowdloanAppBonusFormat(
            referralViewModel.bonusPercentage
        )

        rootView.bonusView.valueLabel.text = referralViewModel.bonusValue

        if referralViewModel.canApplyDefaultCode {
            rootView.applyAppBonusButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonApply().uppercased()

            rootView.applyAppBonusButton.isEnabled = true
            rootView.applyAppBonusButton.applyDefaultStyle()
        } else {
            rootView.applyAppBonusButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonApplied().uppercased()

            rootView.applyAppBonusButton.isEnabled = false
            rootView.applyAppBonusButton.applyDisabledStyle()
        }

        rootView.applyAppBonusButton.invalidateLayout()

        rootView.termsSwitchView.isOn = referralViewModel.isTermsAgreed

        if !referralViewModel.isCodeReceived {
            rootView.actionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.karuraReferralCodeAction()
        } else if !referralViewModel.isTermsAgreed {
            rootView.actionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.karuraTermsAction()
        } else {
            rootView.actionButton.imageWithTitleView?.title = R.string(
                preferredLanguages: selectedLocale.rLanguages
            ).localizable.commonApply()
        }

        rootView.actionButton.invalidateLayout()

        rootView.setNeedsLayout()
    }

    @objc private func actionSwitchTerms() {
        presenter.setTermsAgreed(value: rootView.termsSwitchView.isOn)
    }

    @objc private func actionApplyDefaultCode() {
        presenter.applyDefaultCode()

        rootView.codeInputView.animatedInputField.textField.resignFirstResponder()
    }

    @objc private func actionCodeChanged(_ sender: UITextField) {
        if codeInputViewModel?.inputHandler.value != sender.text {
            sender.text = codeInputViewModel?.inputHandler.value
        }

        presenter.update(referralCode: codeInputViewModel?.inputHandler.value ?? "")
    }

    @objc private func actionApplyInputCode() {
        presenter.applyInputCode()
    }

    @objc private func actionTapTerms(_ sender: UIGestureRecognizer) {
        if sender.state == .ended {
            presenter.presentTerms()
        }
    }

    @objc private func actionLearnMore() {
        presenter.presentLearnMore()
    }
}

extension ReferralCrowdloanViewController: AnimatedTextFieldDelegate {
    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let viewModel = codeInputViewModel else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }

    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }
}

extension ReferralCrowdloanViewController: ReferralCrowdloanViewProtocol {
    func didReceiveLearnMore(viewModel: LearnMoreViewModel) {
        rootView.learnMoreView.bind(viewModel: viewModel)
    }

    func didReceiveReferral(viewModel: ReferralCrowdloanViewModel) {
        referralViewModel = viewModel

        applyReferralViewModel()
    }

    func didReceiveInput(viewModel: InputViewModelProtocol) {
        codeInputViewModel = viewModel

        rootView.codeInputView.animatedInputField.text = viewModel.inputHandler.value
    }

    func didReceiveShouldInputCode() {
        rootView.codeInputView.animatedInputField.becomeFirstResponder()
    }

    func didReceiveShouldAgreeTerms() {
        ShakeAnimator(
            duration: 0.5,
            options: [.curveEaseInOut]
        ).animate(view: rootView.termsSwitchView, completionBlock: nil)
    }
}

extension ReferralCrowdloanViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
