import Foundation
import SubstrateSdk

indirect enum NestedCallNode<T: Codable> {
    case proxy(proxiedAccountId: AccountId, child: NestedCallNode<T>)
    case batch(children: [NestedCallNode<T>])
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

extension NestedCallNode where T == JSON {
    func mapCall<C: Codable>(closure: (JSON) throws -> C) throws -> NestedCallNode<C> {
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

protocol NestedCallMapperProtocol {
    func map(
        call: JSON,
        context: RuntimeJsonContext?,
        matchingClosure: (JSON) -> Bool
    ) throws -> NestedCallNode<JSON>
}

enum NestedCallMapperError: Error {
    case internalError(JSON)
    case noMatch(JSON)
}

extension NestedCallMapperProtocol {
    func mapRuntimeCall<T: Codable>(
        call: JSON,
        context: RuntimeJsonContext?
    ) throws -> NestedCallNode<RuntimeCall<T>> {
        let node = try map(call: call, context: context) { callJson in
            do {
                _ = try callJson.map(to: RuntimeCall<T>.self, with: context?.toRawContext())
                return true
            } catch {
                return false
            }
        }

        return try node.mapCall { callJson in
            try callJson.map(to: RuntimeCall<T>.self, with: context?.toRawContext())
        }
    }

    func mapNotNestedCall(
        call: JSON,
        context: RuntimeJsonContext?
    ) throws -> NestedCallNode<RuntimeCall<NoRuntimeArgs>> {
        let nestedCallPaths: Set<CallCodingPath> = [
            Proxy.ProxyCall.callPath,
            UtilityPallet.batchPath,
            UtilityPallet.batchPath,
            UtilityPallet.forceBatchPath
        ]

        let node = try map(call: call, context: context) { callJson in
            do {
                let call = try callJson.map(to: RuntimeCall<NoRuntimeArgs>.self, with: context?.toRawContext())
                let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
                return !nestedCallPaths.contains(callPath)
            } catch {
                return false
            }
        }

        return try node.mapCall { callJson in
            try callJson.map(to: RuntimeCall<NoRuntimeArgs>.self, with: context?.toRawContext())
        }
    }

    func mapProxiedAndCall(
        call: JSON,
        context: RuntimeJsonContext?
    ) throws -> (AccountId?, AnyRuntimeCall) {
        let proxyCallPaths: Set<CallCodingPath> = [
            Proxy.ProxyCall.callPath
        ]

        let node = try map(call: call, context: context) { callJson in
            do {
                let call = try callJson.map(to: RuntimeCall<NoRuntimeArgs>.self, with: context?.toRawContext())
                let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
                return !proxyCallPaths.contains(callPath)
            } catch {
                return false
            }
        }

        guard let jsonCall = node.calls.first else {
            throw NestedCallMapperError.noMatch(call)
        }

        let runtimeCall = try jsonCall.map(to: AnyRuntimeCall.self, with: context?.toRawContext())

        return (node.callSender, runtimeCall)
    }
}

final class NestedCallMapper {
    func mapConcrete(call: JSON, matchingClosure: (JSON) -> Bool) throws -> NestedCallNode<JSON> {
        if matchingClosure(call) {
            return .call(call)
        } else {
            throw NestedCallMapperError.noMatch(call)
        }
    }

    func mapProxy(
        call: JSON,
        context: RuntimeJsonContext?,
        matchingClosure: (JSON) -> Bool
    ) throws -> NestedCallNode<JSON> {
        let proxyCall: RuntimeCall<Proxy.ProxyCall> = try ExtrinsicExtraction.getTypedCall(
            from: call,
            context: context
        )

        let node: NestedCallNode<JSON> = try mapNested(
            call: proxyCall.args.call,
            context: context,
            matchingClosure: matchingClosure
        )

        guard let proxiedAccountId = proxyCall.args.real.accountId else {
            throw NestedCallMapperError.internalError(call)
        }

        return .proxy(proxiedAccountId: proxiedAccountId, child: node)
    }

    func mapBatch(
        call: JSON,
        context: RuntimeJsonContext?,
        matchingClosure: (JSON) -> Bool
    ) throws -> NestedCallNode<JSON> {
        let batchCall: RuntimeCall<UtilityPallet.Call> = try ExtrinsicExtraction.getTypedCall(
            from: call,
            context: context
        )

        let children: [NestedCallNode<JSON>] = batchCall.args.calls.compactMap { childCall in
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
            throw NestedCallMapperError.noMatch(call)
        }

        return .batch(children: children)
    }

    func mapNested(
        call: JSON,
        context: RuntimeJsonContext?,
        matchingClosure: (JSON) -> Bool
    ) throws -> NestedCallNode<JSON> {
        let optNode: NestedCallNode<JSON>? = try? mapConcrete(call: call, matchingClosure: matchingClosure)

        if let node = optNode {
            return node
        } else if let proxyNode = try? mapProxy(call: call, context: context, matchingClosure: matchingClosure) {
            return proxyNode
        } else {
            return try mapBatch(call: call, context: context, matchingClosure: matchingClosure)
        }
    }
}

extension NestedCallMapper: NestedCallMapperProtocol {
    func map(
        call: JSON,
        context: RuntimeJsonContext?,
        matchingClosure: (JSON) -> Bool
    ) throws -> NestedCallNode<JSON> {
        try mapNested(
            call: call,
            context: context,
            matchingClosure: matchingClosure
        )
    }
}
