import Foundation
import SubstrateSdk

protocol RuntimeCallBuilding: AnyObject {
    func addingFirst<A: Encodable>(_ call: RuntimeCall<A>) throws -> Self
    func addingLast<A: Encodable>(_ call: RuntimeCall<A>) throws -> Self
    func dispatchingAs(_ origin: RuntimeCallOrigin) throws -> Self
    func batching(_ batchType: UtilityPallet.BatchType) throws -> Self
    func build() throws -> AnyRuntimeCall
}

enum RuntimeCallBuilderError: Error {
    case noCalls
}

final class RuntimeCallBuilder {
    let context: RuntimeJsonContext
    private var calls: [AnyRuntimeCall] = []

    init(context: RuntimeJsonContext) {
        self.context = context
    }
}

private extension RuntimeCallBuilder {
    func finalizeCall() throws -> AnyRuntimeCall {
        guard !calls.isEmpty else {
            throw RuntimeCallBuilderError.noCalls
        }

        if calls.count > 1 {
            return try AnyRuntimeCall(
                path: UtilityPallet.batchAllPath,
                args: UtilityPallet.Call(calls: calls),
                context: context
            )
        } else {
            return calls[0]
        }
    }
}

extension RuntimeCallBuilder: RuntimeCallBuilding {
    func addingFirst<A: Encodable>(_ call: RuntimeCall<A>) throws -> Self {
        let anyCall = try call.anyRuntimeCall(with: context)

        calls.insert(anyCall, at: 0)

        return self
    }

    func addingLast<A: Encodable>(_ call: RuntimeCall<A>) throws -> Self {
        let anyCall = try call.anyRuntimeCall(with: context)

        calls.append(anyCall)

        return self
    }

    func dispatchingAs(_ origin: RuntimeCallOrigin) throws -> Self {
        let call = try finalizeCall()

        let wrappedCall = try UtilityPallet.DispatchAs(
            asOrigin: origin,
            call: call
        )
        .runtimeCall()
        .anyRuntimeCall(with: context)

        calls = [wrappedCall]

        return self
    }

    func batching(_ batchType: UtilityPallet.BatchType) throws -> Self {
        let call = try AnyRuntimeCall(
            path: batchType.path,
            args: UtilityPallet.Call(calls: calls),
            context: context
        )

        calls = [call]

        return self
    }

    func build() throws -> AnyRuntimeCall {
        try finalizeCall()
    }
}
