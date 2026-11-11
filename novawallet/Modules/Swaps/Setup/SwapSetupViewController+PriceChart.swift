import UIKit
import Foundation_iOS

extension SwapSetupViewController {
    var isChartVisiblyExpanded: Bool {
        guard isOnScreen, !isKeyboardVisible, presentedViewController == nil else {
            return false
        }

        return chartViewModel?.isExpanded ?? false
    }

    func setupPriceChart() {
        chartViewProvider.setupView(on: self, view: rootView.chartContainerView)
        chartViewProvider.expansionDelegate = self

        applyChartExpansion(animated: false)
    }

    func didReceiveChart(viewModel: SwapPriceChartViewModel) {
        guard viewModel != chartViewModel else {
            return
        }

        let animated = chartViewModel != nil && viewIfLoaded?.window != nil

        chartViewModel = viewModel

        applyChartExpansion(animated: animated)
    }
}

// MARK: Private

private extension SwapSetupViewController {
    func applyChartExpansion(animated: Bool) {
        let viewModel = chartViewModel ?? SwapPriceChartViewModel(isExpanded: false, isExpandable: true)
        let isExpanded = viewModel.isExpanded && !isKeyboardVisible

        chartViewProvider.setExpansion(
            isExpanded: isExpanded,
            isExpandable: viewModel.isExpandable,
            animated: animated
        )

        rootView.setChartHeight(chartViewProvider.getProposedHeight(), isExpanded: isExpanded)

        guard animated else {
            return
        }

        UIView.animate(withDuration: AssetPriceChartViewLayout.CompactConstants.animationDuration) {
            self.rootView.layoutIfNeeded()
        }
    }

    func focusedInputView() -> UIView? {
        if rootView.payAmountInputView.textInputView.textField.isFirstResponder {
            rootView.payAmountInputView
        } else if rootView.receiveAmountInputView.textInputView.textField.isFirstResponder {
            rootView.receiveAmountInputView
        } else {
            nil
        }
    }
}

// MARK: AssetPriceChartExpansionDelegate

extension SwapSetupViewController: AssetPriceChartExpansionDelegate {
    func priceChartDidRequestExpansion(_ isExpanded: Bool) {
        if isExpanded {
            view.endEditing(true)
        }

        presenter.selectChartExpansion(isExpanded)
    }
}

// MARK: KeyboardAdoptable

extension SwapSetupViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = max(0, view.bounds.height - localKeyboardFrame.minY)
        let scrollView = rootView.containerView.scrollView
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets

        let keyboardVisible = bottomInset > 0

        if keyboardVisible != isKeyboardVisible {
            isKeyboardVisible = keyboardVisible

            applyChartExpansion(animated: false)
            rootView.layoutIfNeeded()
        }

        guard keyboardVisible, let inputView = focusedInputView() else {
            return
        }

        let inputFrame = scrollView.convert(inputView.frame, from: inputView.superview)
        scrollView.scrollRectToVisible(inputFrame, animated: true)
    }
}

// MARK: KeyboardHandlerDelegate

extension SwapSetupViewController: KeyboardHandlerDelegate {
    func keyboardDidHide(notification _: Notification) {
        presenter.didChangeChartVisibility()
    }
}
