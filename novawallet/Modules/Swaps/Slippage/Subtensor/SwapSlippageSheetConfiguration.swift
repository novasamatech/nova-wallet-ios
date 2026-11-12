import Foundation
import Foundation_iOS

struct SwapSlippageSheetConfiguration {
    let title: LocalizableResource<String>
    let slippageTitle: LocalizableResource<String>
    let explanation: LocalizableResource<String>?
    let actionTitle: LocalizableResource<String>
    let allowsReset: Bool
    let showsSlippageInfo: Bool
}

extension SwapSlippageSheetConfiguration {
    static let subtensor = SwapSlippageSheetConfiguration(
        title: LocalizableResource { R.string(preferredLanguages: $0.rLanguages).localizable.commonButtonSettings() },
        slippageTitle: LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.stakingSubtensorInfoSlippageTitle()
        },
        explanation: LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.stakingSubtensorUiSlippageExplanation()
        },
        actionTitle: LocalizableResource { R.string(preferredLanguages: $0.rLanguages).localizable.commonDone() },
        allowsReset: false,
        showsSlippageInfo: false
    )

    static let swap = SwapSlippageSheetConfiguration(
        title: LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.swapsSetupSettingsTitle()
        },
        slippageTitle: LocalizableResource {
            R.string(preferredLanguages: $0.rLanguages).localizable.swapsSetupSlippage()
        },
        explanation: nil,
        actionTitle: LocalizableResource { R.string(preferredLanguages: $0.rLanguages).localizable.commonApply() },
        allowsReset: true,
        showsSlippageInfo: true
    )
}
