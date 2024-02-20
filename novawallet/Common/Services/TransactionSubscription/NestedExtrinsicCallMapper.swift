import Foundation
import SubstrateSdk

indirect enum NestedExtrinsicCallNode<T: Codable> {
    case proxy(proxiedAccountId: AccountId, child: NestedExtrinsicCallNode<T>)
    case batch(children: [NestedExtrinsicCallNode<T>])
    case call(T)

    var callSender: AccountId? {
        switch self {
        case let .proxy(proxiedAccountId, child):
            if let nestedCallOwner = child.callSender {
                return nestedCallOwner
            } else {
                return proxiedAccountId
            }
        case let .batch(children):
            let callSenders = children.compactMap(\.callSender)
            return callSenders.first
        case .call:
            return nil
        }
    }

    var calls: [T] {
        switch self {
        case let .proxy(_, child):
            return child.calls
        case let .batch(children):
            return children.flatMap(\.calls)
        case let .call(runtimeCall):
            return [runtimeCall]
        }
    }
}

extension NestedExtrinsicCallNode where T == JSON {
    func mapCall<T: Codable>(closure: (JSON) throws -> T) throws -> NestedExtrinsicCallNode<T> {
        switch self {
        case let .proxy(proxiedAccountId, child):
            let newChild = try child.mapCall(closure: closure)
            return .proxy(proxiedAccountId: proxiedAccountId, child: newChild)
        case let .batch(children):
            let newChildren = try children.map { try $0.mapCall(closure: closure) }
            return .batch(children: newChildren)
        case let .call(call):
            let newCall = try closure(call)
            return .call(newCall)
        }
    }
}

enum NestedExtrinsicCallMapResultError: Error {
    case noCall
}

struct NestedExtrinsicCallMapResult<T: Codable> {
    let extrinsicSender: AccountId
    let node: NestedExtrinsicCallNode<T>

    var callSender: AccountId {
        if let nestedCallSender = node.callSender {
            return nestedCallSender
        } else {
            return extrinsicSender
        }
    }

    func getFirstCallOrThrow() throws -> T {
        if let call = node.calls.first {
            return call
        } else {
            throw NestedExtrinsicCallMapResultError.noCall
        }
    }
}

protocol NestedExtrinsicCallMapperProtocol {
    func map(
        call: JSON,
        context: RuntimeJsonContext?,
        matchingClosure: (JSON) -> Bool
    ) throws -> NestedExtrinsicCallMapResult<JSON>
}

extension NestedExtrinsicCallMapperProtocol {
    func mapRuntimeCall<T: Codable>(
        call: JSON,
        context: RuntimeJsonContext?
    ) throws -> NestedExtrinsicCallMapResult<RuntimeCall<T>> {
        let result = try map(call: call, context: context) { callJson in
            do {
                _ = try callJson.map(to: RuntimeCall<T>.self, with: context?.toRawContext())
                return true
            } catch {
                return false
            }
        }

        let newNode: NestedExtrinsicCallNode<RuntimeCall<T>> = try result.node.mapCall { callJson in
            try callJson.map(to: RuntimeCall<T>.self, with: context?.toRawContext())
        }

        return NestedExtrinsicCallMapResult(
            extrinsicSender: result.extrinsicSender,
            node: newNode
        )
    }

    func mapNotNestedCall(
        call: JSON,
        context: RuntimeJsonContext?
    ) throws -> NestedExtrinsicCallMapResult<RuntimeCall<NoRuntimeArgs>> {
        let nestedCallPaths: Set<CallCodingPath> = [
            Proxy.ProxyCall.callPath,
            UtilityPallet.batchPath,
            UtilityPallet.batchPath,
            UtilityPallet.forceBatchPath
        ]

        let result = try map(call: call, context: context) { callJson in
            do {
                let call = try callJson.map(to: RuntimeCall<NoRuntimeArgs>.self, with: context?.toRawContext())
                let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
                return !nestedCallPaths.contains(callPath)
            } catch {
                return false
            }
        }

        let newNode: NestedExtrinsicCallNode<RuntimeCall<NoRuntimeArgs>> = try result.node.mapCall { callJson in
            try callJson.map(to: RuntimeCall<NoRuntimeArgs>.self, with: context?.toRawContext())
        }

        return NestedExtrinsicCallMapResult(
            extrinsicSender: result.extrinsicSender,
            node: newNode
        )
    }
}

final class NestedExtrinsicCallMapper {
    enum NestedExtrinsicCallMapperError: Error {
        case internalError(JSON)
        case noMatch(JSON)
    }

    let extrinsicSender: AccountId

    init(extrinsicSender: AccountId) {
        self.extrinsicSender = extrinsicSender
    }

    func mapConcrete(call: JSON, matchingClosure: (JSON) -> Bool) throws -> NestedExtrinsicCallNode<JSON> {
        if matchingClosure(call) {
            return .call(call)
        } else {
            throw NestedExtrinsicCallMapperError.noMatch(call)
        }
    }

    func mapProxy(
        call: JSON,
        context: RuntimeJsonContext?,
        matchingClosure: (JSON) -> Bool
    ) throws -> NestedExtrinsicCallNode<JSON> {
        let proxyCall: RuntimeCall<Proxy.ProxyCall> = try ExtrinsicExtraction.getTypedCall(
            from: call,
            context: context
        )

        let node: NestedExtrinsicCallNode<JSON> = try mapNested(
            call: proxyCall.args.call,
            context: context,
            matchingClosure: matchingClosure
        )

        guard let proxiedAccountId = proxyCall.args.real.accountId else {
            throw NestedExtrinsicCallMapperError.internalError(call)
        }

        return .proxy(proxiedAccountId: proxiedAccountId, child: node)
    }

    func mapBatch(
        call: JSON,
        context: RuntimeJsonContext?,
        matchingClosure: (JSON) -> Bool
    ) throws -> NestedExtrinsicCallNode<JSON> {
        let batchCall: RuntimeCall<UtilityPallet.Call> = try ExtrinsicExtraction.getTypedCall(
            from: call,
            context: context
        )

        let children: [NestedExtrinsicCallNode<JSON>] = batchCall.args.calls.compactMap { childCall in
            guard let jsonCall = try? childCall.toScaleCompatibleJSON(with: context?.toRawContext()) else {
                return nil
            }

            return try? mapNested(
                call: jsonCall,
                context: context,
                matchingClosure: matchingClosure
            )
        }

        guard !children.isEmpty else {
            throw NestedExtrinsicCallMapperError.noMatch(call)
        }

        return .batch(children: children)
    }

    func mapNested(
        call: JSON,
        context: RuntimeJsonContext?,
        matchingClosure: (JSON) -> Bool
    ) throws -> NestedExtrinsicCallNode<JSON> {
        let optNode: NestedExtrinsicCallNode<JSON>? = try? mapConcrete(call: call, matchingClosure: matchingClosure)

        if let node = optNode {
            return node
        } else if let proxyNode = try? mapProxy(call: call, context: context, matchingClosure: matchingClosure) {
            return proxyNode
        } else {
            return try mapBatch(call: call, context: context, matchingClosure: matchingClosure)
        }
    }
}

extension NestedExtrinsicCallMapper: NestedExtrinsicCallMapperProtocol {
    func map(
        call: JSON,
        context: RuntimeJsonContext?,
        matchingClosure: (JSON) -> Bool
    ) throws -> NestedExtrinsicCallMapResult<JSON> {
        let node: NestedExtrinsicCallNode<JSON> = try mapNested(
            call: call,
            context: context,
            matchingClosure: matchingClosure
        )

        return NestedExtrinsicCallMapResult(extrinsicSender: extrinsicSender, node: node)
    }
}
