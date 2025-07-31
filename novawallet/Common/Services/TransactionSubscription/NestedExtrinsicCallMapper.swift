import Foundation
import SubstrateSdk

enum NestedExtrinsicCallMapResultError: Error {
    case noCall
}

struct NestedExtrinsicCallMapResult<T: Codable> {
    let extrinsicSender: AccountId
    let node: NestedCallNode<T>

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

    func mapRuntimeCall<T: Codable>(
        call: JSON,
        context: RuntimeJsonContext?
    ) throws -> NestedExtrinsicCallMapResult<RuntimeCall<T>>

    func mapNotNestedCall(
        call: JSON,
        context: RuntimeJsonContext?
    ) throws -> NestedExtrinsicCallMapResult<RuntimeCall<NoRuntimeArgs>>
}

final class NestedExtrinsicCallMapper {
    let extrinsicSender: AccountId
    let callMapper = NestedCallMapper()

    init(extrinsicSender: AccountId) {
        self.extrinsicSender = extrinsicSender
    }
}

extension NestedExtrinsicCallMapper: NestedExtrinsicCallMapperProtocol {
    func map(
        call: JSON,
        context: RuntimeJsonContext?,
        matchingClosure: (JSON) -> Bool
    ) throws -> NestedExtrinsicCallMapResult<JSON> {
        let node: NestedCallNode<JSON> = try callMapper.map(
            call: call,
            context: context,
            matchingClosure: matchingClosure
        )

        return NestedExtrinsicCallMapResult(extrinsicSender: extrinsicSender, node: node)
    }

    func mapRuntimeCall<T: Codable>(
        call: JSON,
        context: RuntimeJsonContext?
    ) throws -> NestedExtrinsicCallMapResult<RuntimeCall<T>> {
        let node: NestedCallNode<RuntimeCall<T>> = try callMapper.mapRuntimeCall(
            call: call,
            context: context
        )

        return NestedExtrinsicCallMapResult(
            extrinsicSender: extrinsicSender,
            node: node
        )
    }

    func mapNotNestedCall(
        call: JSON,
        context: RuntimeJsonContext?
    ) throws -> NestedExtrinsicCallMapResult<RuntimeCall<NoRuntimeArgs>> {
        let newNode: NestedCallNode<RuntimeCall<NoRuntimeArgs>> = try callMapper.mapNotNestedCall(
            call: call,
            context: context
        )

        return NestedExtrinsicCallMapResult(
            extrinsicSender: extrinsicSender,
            node: newNode
        )
    }
}
