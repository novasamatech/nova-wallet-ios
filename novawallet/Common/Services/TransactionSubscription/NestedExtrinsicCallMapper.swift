import Foundation
import SubstrateSdk

indirect enum NestedExtrinsicCallNode<T: Codable> {
    case proxy(proxiedAccountId: AccountId, child: NestedExtrinsicCallNode<T>)
    case call(T)

    var isCall: Bool {
        switch self {
        case .proxy:
            return false
        case .call:
            return true
        }
    }

    var callSender: AccountId? {
        switch self {
        case let .proxy(proxiedAccountId, child):
            if let nestedCallOwner = child.callSender {
                return nestedCallOwner
            } else {
                return proxiedAccountId
            }
        case .call:
            return nil
        }
    }

    var call: T {
        switch self {
        case let .proxy(_, child):
            return child.call
        case let .call(runtimeCall):
            return runtimeCall
        }
    }
}

extension NestedExtrinsicCallNode where T == JSON {
    func mapCall<T: Codable>(closure: (JSON) throws -> T) throws -> NestedExtrinsicCallNode<T> {
        switch self {
        case let .proxy(proxiedAccountId, child):
            let newChild = try child.mapCall(closure: closure)
            return .proxy(proxiedAccountId: proxiedAccountId, child: newChild)
        case let .call(call):
            let newCall = try closure(call)
            return .call(newCall)
        }
    }
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

    var call: T {
        node.call
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
        let proxyCall = try call.map(to: RuntimeCall<Proxy.ProxyCall>.self, with: context?.toRawContext())
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

    func mapNested(
        call: JSON,
        context: RuntimeJsonContext?,
        matchingClosure: (JSON) -> Bool
    ) throws -> NestedExtrinsicCallNode<JSON> {
        let optNode: NestedExtrinsicCallNode<JSON>? = try? mapConcrete(call: call, matchingClosure: matchingClosure)

        if let node = optNode {
            return node
        } else {
            return try mapProxy(call: call, context: context, matchingClosure: matchingClosure)
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
