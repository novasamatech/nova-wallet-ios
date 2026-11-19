import Foundation
import Foundation_iOS

struct SwapSlippageSheetConfiguration {
    enum Presentation {
        case sheet
        case card
    }

    let title: LocalizableResource<String>
    let slippageTitle: LocalizableResource<String>
    let explanation: LocalizableResource<String>?
    let actionTitle: LocalizableResource<String>
    let allowsReset: Bool
    let showsSlippageInfo: Bool
    let presentation: Presentation
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
        showsSlippageInfo: false,
        presentation: .sheet
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
        showsSlippageInfo: true,
        presentation: .card
    )
}
