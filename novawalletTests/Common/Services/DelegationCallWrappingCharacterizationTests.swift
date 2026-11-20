@testable import novawallet
import SubstrateSdk
import XCTest

/// Pins how sender resolution rewrites a call for delegated wallets: `proxy.proxy` for proxied accounts and
/// `multisig.as_multi(_threshold_1)` for multisigs, on the Polkadot Asset Hub fixture.
/// Golden values were recorded on substrate-sdk-ios 4.5.2.
final class DelegationCallWrappingCharacterizationTests: XCTestCase {
    typealias PathFinder = DelegationResolution.PathFinder

    private var runtime: ExtrinsicGoldenRuntime!

    private var context: RuntimeJsonContext { runtime.codingFactory.createRuntimeJsonContext() }

    override func setUpWithError() throws {
        runtime = try ExtrinsicGoldenRuntime.polkadotAssetHub()
    }

    // MARK: Path values

    func testProxyValueWrapsCallIntoProxyProxy() throws {
        let value = PathFinder.ProxyDelegationValue(metaId: "proxied", proxyType: .any)

        let wrapped = try value.wrapCall(
            makeTransferJson(),
            delegatedAccountId: ExtrinsicGolden.senderId,
            delegateAccountId: ExtrinsicGolden.thirdPartyId,
            context: context
        )

        XCTAssertFalse(value.delaysCallExecution())
        XCTAssertEqual(try ExtrinsicGolden.json(wrapped), #"{"args":{"call":{"args":{"dest":["Id","0x2222222222222222222222222222222222222222222222222222222222222222"],"value":"1000000000000"},"callName":"transfer_keep_alive","moduleName":"Balances"},"force_proxy_type":["Any",null],"real":["Id","0x1111111111111111111111111111111111111111111111111111111111111111"]},"callName":"proxy","moduleName":"Proxy"}"#)
        XCTAssertEqual(try runtime.encodeCall(wrapped), "0x2a0000111111111111111111111111111111111111111111111111111111111111111101000a03002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testProxyValueKeepsNonDefaultProxyType() throws {
        let value = PathFinder.ProxyDelegationValue(metaId: "proxied", proxyType: .nonTransfer)

        let wrapped = try value.wrapCall(
            makeTransferJson(),
            delegatedAccountId: ExtrinsicGolden.senderId,
            delegateAccountId: ExtrinsicGolden.thirdPartyId,
            context: context
        )

        XCTAssertEqual(try runtime.encodeCall(wrapped), "0x2a0000111111111111111111111111111111111111111111111111111111111111111101010a03002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    func testMultisigValueWrapsCallIntoAsMultiWithSortedOtherSignatories() throws {
        let value = PathFinder.MultisigDelegationValue(
            metaId: "multisig",
            threshold: 2,
            signatories: [ExtrinsicGolden.thirdPartyId, ExtrinsicGolden.senderId, ExtrinsicGolden.receiverId]
        )

        let wrapped = try value.wrapCall(
            makeTransferJson(),
            delegatedAccountId: Data(repeating: 0x44, count: 32),
            delegateAccountId: ExtrinsicGolden.senderId,
            context: context
        )

        XCTAssertTrue(value.delaysCallExecution())
        XCTAssertEqual(try ExtrinsicGolden.json(wrapped), #"{"args":{"call":{"args":{"dest":["Id","0x2222222222222222222222222222222222222222222222222222222222222222"],"value":"1000000000000"},"callName":"transfer_keep_alive","moduleName":"Balances"},"max_weight":{"proofSize":"0","refTime":"0"},"maybe_timepoint":null,"other_signatories":[["34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34","34"],["51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51"]],"threshold":"2"},"callName":"as_multi","moduleName":"Multisig"}"#)
        XCTAssertEqual(try runtime.encodeCall(wrapped), "0x290102000822222222222222222222222222222222222222222222222222222222222222223333333333333333333333333333333333333333333333333333333333333333000a03002222222222222222222222222222222222222222222222222222222222222222070010a5d4e80000")
    }

    func testMultisigValueWithThresholdOneUsesAsMultiThreshold1() throws {
        let value = PathFinder.MultisigDelegationValue(
            metaId: "multisig",
            threshold: 1,
            signatories: [ExtrinsicGolden.thirdPartyId, ExtrinsicGolden.senderId]
        )

        let wrapped = try value.wrapCall(
            makeTransferJson(),
            delegatedAccountId: Data(repeating: 0x44, count: 32),
            delegateAccountId: ExtrinsicGolden.senderId,
            context: context
        )

        XCTAssertFalse(value.delaysCallExecution())
        XCTAssertEqual(try ExtrinsicGolden.json(wrapped), #"{"args":{"call":{"args":{"dest":["Id","0x2222222222222222222222222222222222222222222222222222222222222222"],"value":"1000000000000"},"callName":"transfer_keep_alive","moduleName":"Balances"},"other_signatories":[["51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51","51"]]},"callName":"as_multi_threshold_1","moduleName":"Multisig"}"#)
        XCTAssertEqual(try runtime.encodeCall(wrapped), "0x29000433333333333333333333333333333333333333333333333333333333333333330a03002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8")
    }

    // MARK: Call wrappers

    func testProxyWrapperWrapsSingleCall() throws {
        let proxied = makeAccount(ExtrinsicGolden.senderId, type: .proxied)
        let proxy = makeAccount(ExtrinsicGolden.thirdPartyId, type: .secrets)
        let solution = makeSolution(
            delegate: proxy,
            components: [.init(account: makeMetaAccount(proxy), delegationValue: makeProxyValue())]
        )

        let result = try DelegatedCallWrapperFactory.createCallWrapper(
            for: proxied,
            delegateAccountId: proxy.accountId
        )
        .wrapCalls(using: solution, builder: makeBuilder(callsCount: 1), coderFactory: runtime.codingFactory)

        XCTAssertEqual(result.path.components.count, 1)
        XCTAssertEqual(try encodeCalls(of: result.builder), ["0x2a0000111111111111111111111111111111111111111111111111111111111111111101000a03002222222222222222222222222222222222222222222222222222222222222222070010a5d4e8"])
    }

    func testProxyWrapperWrapsEachCallAndBatches() throws {
        let proxied = makeAccount(ExtrinsicGolden.senderId, type: .proxied)
        let proxy = makeAccount(ExtrinsicGolden.thirdPartyId, type: .secrets)
        let solution = makeSolution(
            delegate: proxy,
            components: [.init(account: makeMetaAccount(proxy), delegationValue: makeProxyValue())]
        )

        let result = try DelegatedCallWrapperFactory.createCallWrapper(
            for: proxied,
            delegateAccountId: proxy.accountId
        )
        .wrapCalls(using: solution, builder: makeBuilder(callsCount: 2), coderFactory: runtime.codingFactory)

        XCTAssertTrue(result.path.components.isEmpty)
        XCTAssertEqual(try encodeCalls(of: result.builder), ["0x2802082a0000111111111111111111111111111111111111111111111111111111111111111101000a03002222222222222222222222222222222222222222222222222222222222222222070010a5d4e82a0000111111111111111111111111111111111111111111111111111111111111111101000a03002222222222222222222222222222222222222222222222222222222222222222070110a5d4e8"])
    }

    func testMultisigWrapperBatchesThenWrapsIntoAsMulti() throws {
        let multisig = makeAccount(Data(repeating: 0x44, count: 32), type: .multisig)
        let signatory = makeAccount(ExtrinsicGolden.senderId, type: .secrets)
        let value = PathFinder.MultisigDelegationValue(
            metaId: multisig.metaId,
            threshold: 2,
            signatories: [ExtrinsicGolden.senderId, ExtrinsicGolden.receiverId, ExtrinsicGolden.thirdPartyId]
        )
        let solution = makeSolution(
            delegate: signatory,
            components: [.init(account: makeMetaAccount(signatory), delegationValue: value)]
        )

        let result = try DelegatedCallWrapperFactory.createCallWrapper(
            for: multisig,
            delegateAccountId: signatory.accountId
        )
        .wrapCalls(using: solution, builder: makeBuilder(callsCount: 2), coderFactory: runtime.codingFactory)

        XCTAssertEqual(result.path.components.count, 1)
        XCTAssertEqual(try encodeCalls(of: result.builder), ["0x290102000822222222222222222222222222222222222222222222222222222222222222223333333333333333333333333333333333333333333333333333333333333333002802080a03002222222222222222222222222222222222222222222222222222222222222222070010a5d4e80a03002222222222222222222222222222222222222222222222222222222222222222070110a5d4e80000"])
    }

    func testSecretsAccountHasNoCallWrapper() {
        let account = makeAccount(ExtrinsicGolden.senderId, type: .secrets)

        XCTAssertThrowsError(
            try DelegatedCallWrapperFactory.createCallWrapper(for: account, delegateAccountId: account.accountId)
        )
    }
}

private extension DelegationCallWrappingCharacterizationTests {
    func makeTransferJson() throws -> JSON {
        try ExtrinsicGolden.transferCall().toScaleCompatibleJSON(with: context.toRawContext())
    }

    func makeProxyValue() -> PathFinder.ProxyDelegationValue {
        PathFinder.ProxyDelegationValue(metaId: "proxied", proxyType: .any)
    }

    func makeBuilder(callsCount: Int) throws -> ExtrinsicBuilderProtocol {
        var builder = try runtime.makeBuilder()

        for index in 0 ..< callsCount {
            builder = try builder.adding(call: ExtrinsicGolden.transferCall(amount: ExtrinsicGolden.amount + .init(index)))
        }

        return builder
    }

    func makeAccount(_ accountId: AccountId, type: MetaAccountModelType) -> ChainAccountResponse {
        ChainAccountResponse(
            metaId: accountId.toHex(),
            chainId: KnowChainId.polkadotAssetHub,
            accountId: accountId,
            publicKey: accountId,
            name: "Golden",
            cryptoType: .sr25519,
            addressPrefix: 0,
            isEthereumBased: false,
            isChainAccount: false,
            type: type
        )
    }

    func makeMetaAccount(_ account: ChainAccountResponse) -> MetaChainAccountResponse {
        MetaChainAccountResponse(
            metaId: account.metaId,
            substrateAccountId: account.accountId,
            ethereumAccountId: nil,
            walletIdenticonData: nil,
            delegationId: nil,
            chainAccount: account
        )
    }

    func makeSolution(
        delegate: ChainAccountResponse,
        components: [DelegationResolution.PathFinderPath.Component]
    ) -> DelegationResolution.PathFinderResult {
        DelegationResolution.PathFinderResult(
            delegate: makeMetaAccount(delegate),
            callToPath: [.transferKeepAlive: .init(components: components)]
        )
    }

    func encodeCalls(of builder: ExtrinsicBuilderProtocol) throws -> [String] {
        try builder.getCalls().map { try runtime.encodeCall($0) }
    }
}
