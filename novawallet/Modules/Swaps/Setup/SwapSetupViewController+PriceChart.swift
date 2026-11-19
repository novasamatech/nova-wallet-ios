import UIKit
import Foundation_iOS

extension SwapSetupViewController {
    var isChartShownExpanded: Bool {
        let isExpanded = chartViewModel?.isExpanded ?? false

        return isExpanded && !isKeyboardVisible && !isChartCollapsedByDetails
    }

    var isChartCollapsedByDetails: Bool {
        isChartCollapseRequestedByDetails && !isDetailsCardSettledHidden
    }

    func updateChartExpansion(animated: Bool) {
        let isExpanded = isChartShownExpanded

        chartViewProvider.setExpansion(
            isExpanded: isExpanded,
            isExpandable: chartViewModel?.isExpandable ?? true,
            animated: animated
        )

        rootView.setChartHeight(chartViewProvider.getProposedHeight(), isExpanded: isExpanded)
    }

    func applyChartCollapseByDetailsChange() {
        applyChartExpansion(animated: viewIfLoaded?.window != nil) {
            self.presenter.didChangeChartVisibility()
        }
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
    func applyChartExpansion(animated: Bool, completion: (() -> Void)? = nil) {
        updateChartExpansion(animated: animated)

        guard animated else {
            completion?()
            return
        }

        UIView.animate(
            withDuration: AssetPriceChartViewLayout.CompactConstants.animationDuration,
            animations: {
                self.rootView.layoutIfNeeded()
            },
            completion: { _ in
                completion?()
            }
        )
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

            if isChartCollapseRequestedByDetails {
                isChartCollapseRequestedByDetails = false
                applyChartExpansion(animated: true)
            }
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
        let scrollViewFrame = view.convert(scrollView.bounds, from: scrollView)
        let scrollViewOffset = view.bounds.height - scrollViewFrame.maxY

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
