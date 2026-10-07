import Foundation

enum SubtensorClaimTapRule {
    enum Verdict: Equatable {
        case nothingToClaim
        case changed(SubtensorRootClaimPreview)
        case proceed(SubtensorRootClaimPreview)
    }

    static func verdict(shown: SubtensorRootClaimPreview, fresh: SubtensorRootClaimable) -> Verdict {
        guard
            let minimumClaim = fresh.minimumClaim,
            let preview = fresh.previews.first(where: { $0.hotkey == shown.hotkey }),
            SubtensorRootClaimRule.isClaimable(preview, minimumClaim: minimumClaim) else {
            return .nothingToClaim
        }

        guard
            !isMaterialDrop(from: shown.redeemable, to: preview.redeemable),
            preview.forfeitedEstimate <= shown.forfeitedEstimate else {
            return .changed(preview)
        }

        return .proceed(preview)
    }
}

private extension SubtensorClaimTapRule {
    static func isMaterialDrop(from shown: Balance, to fresh: Balance) -> Bool {
        guard fresh < shown else {
            return false
        }

        let threshold = SubtensorStakingFlowConstants.priceImpactWarningThreshold

        return (shown - fresh) * threshold.denominator > threshold.numerator * shown
    }
}
