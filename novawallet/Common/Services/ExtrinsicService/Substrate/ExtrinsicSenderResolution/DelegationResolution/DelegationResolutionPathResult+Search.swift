import Foundation
import SubstrateSdk

extension DelegationResolution.PathFinderResult {
    func getFirstMatchingDelegatedPath(
        for calls: [JSON],
        context: RuntimeJsonContext
    ) -> DelegationResolution.PathFinderPath? {
        for callJson in calls {
            if
                let call = try? callJson.map(
                    to: RuntimeCall<NoRuntimeArgs>.self,
                    with: context.toRawContext()
                ),
                let delegatePath = callToPath[call.path] {
                return delegatePath
            }
        }

        return nil
    }
}
