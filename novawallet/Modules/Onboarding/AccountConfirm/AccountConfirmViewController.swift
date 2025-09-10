import UIKit
import Foundation_iOS
import UIKit_iOS
import AudioToolbox

final class AccountConfirmViewController: UIViewController, ViewHolder {
    typealias RootViewType = AccountConfirmViewLayout

    let presenter: AccountConfirmPresenterProtocol

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

    private let showsSkipButton: Bool
    private var wordsUnits: [MnemonicGridView.UnitType] = []

    // MARK: - Lifecycle

    init(
        presenter: AccountConfirmPresenterProtocol,
        localizationManager: LocalizationManagerProtocol,
        showsSkipButton: Bool
    ) {
        self.presenter = presenter
        self.showsSkipButton = showsSkipButton
        super.init(nibName: nil, bundle: nil)
        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        presenter.setup()
        setup()
    }

    override func loadView() {
        view = AccountConfirmViewLayout(showsSkipButton: showsSkipButton)
    }

    // MARK: - Setup functions

    private func setup() {
        setupNavigationItem()
        setupLocalization()

        rootView.delegate = self
        rootView.mnemonicCardView.delegate = self
        rootView.mnemonicGridView.delegate = self
    }

    private func setupNavigationItem() {
        let resetBarButtonItem = UIBarButtonItem(
            title: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonReset(),
            style: .plain,
            target: self,
            action: #selector(actionReset)
        )

        resetBarButtonItem.tintColor = R.color.colorButtonTextAccent()

        navigationItem.rightBarButtonItem = resetBarButtonItem
    }

    private func setupLocalization() {
        rootView.titleLabel.text = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
            .confirmMnemonicTitle()
        rootView.continueButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
            .confirmMnemonicSelectWord()
        rootView.skipButton.imageWithTitleView?.title = R.string(preferredLanguages: selectedLocale.rLanguages).localizable
            .commonSkip()
    }
}

// MARK: AccountConfirmViewProtocol

extension AccountConfirmViewController: AccountConfirmViewProtocol {
    func update(
        with mnemonicCardViewModel: MnemonicCardView.Model,
        gridUnits: [MnemonicGridView.UnitType],
        afterConfirmationFail: Bool
    ) {
        wordsUnits = gridUnits

        if afterConfirmationFail {
            wrongSequenceAnimation.animate(view: rootView.stackView) { _ in
                self.rootView.mnemonicCardView.bind(to: mnemonicCardViewModel)
                self.rootView.mnemonicGridView.bind(with: gridUnits)
                self.updateContinueButton()

                self.retryAnimation.animate(
                    view: self.rootView.stackView,
                    completionBlock: nil
                )
            }

            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        } else {
            rootView.mnemonicCardView.bind(to: mnemonicCardViewModel)
            rootView.mnemonicGridView.bind(with: gridUnits)
            updateContinueButton()
        }
    }
}

// MARK: MnemonicGridViewDelegate

extension AccountConfirmViewController: MnemonicGridViewDelegate {
    func didTap(
        _ mnemonicView: MnemonicGridView,
        _ unit: MnemonicGridView.UnitType
    ) {
        let destinationView: MnemonicGridView

        if mnemonicView is MnemonicCardView {
            destinationView = rootView.mnemonicGridView
        } else {
            destinationView = rootView.mnemonicCardView
        }

        destinationView.requestWordInsert(wordUnit: unit) { coordinator in
            guard let coordinator else { return }

            mnemonicView.setupProposition(for: coordinator)
            coordinator.startTransition(with: self.wordTransitionAnimation)

            self.updateContinueButton()
        }
    }
}

// MARK: AccountConfirmViewLayoutDelegate

extension AccountConfirmViewController: AccountConfirmViewLayoutDelegate {
    func didTapContinue() {
        let words: [String] = rootView.mnemonicCardView
            .units
            .compactMap { cardUnit in
                if case let .wordView(word) = cardUnit {
                    return word
                }

                return nil
            }

        presenter.confirm(words: words)
    }

    func didTapSkip() {
        presenter.skip()
    }
}

// MARK: Private

private extension AccountConfirmViewController {
    func updateContinueButton() {
        let words: [String] = rootView.mnemonicCardView
            .units
            .compactMap { cardUnit in
                if case let .wordView(word) = cardUnit {
                    return word
                }

                return nil
            }

        if words.count == wordsUnits.count {
            rootView.setButtonEnabled(
                with: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.commonContinue()
            )
        } else {
            rootView.setButtonDisabled(
                with: R.string(preferredLanguages: selectedLocale.rLanguages).localizable.confirmMnemonicSelectWord()
            )
        }
    }

    @objc func actionReset() {
        presenter.requestWords()
        retryAnimation.animate(
            view: rootView.stackView,
            completionBlock: nil
        )
    }
}

// MARK: Localizable

extension AccountConfirmViewController: Localizable {
    func applyLocalization() {
        guard isViewLoaded else { return }

        setupLocalization()
    }
}
