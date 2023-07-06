import XCTest
@testable import novawallet

final class SubqueryMultistakingTests: XCTestCase {
    func testPolkadotAndMoonbeamStakings() throws {
        let result = try performSubqueryStateFetch(
            for: "14B3z6xL9vGgKz8WptoZabPrgH6adH1ev2Ven4SiTcdznfqd",
            ethereumAddress: "0xAe1730a04dA7fE52A42C130950f9193BD71690EF"
        )

        Logger.shared.info("Result: \(result)")
    }


    private func performSubqueryStateFetch(
        for substrateAddress: AccountAddress,
        ethereumAddress: AccountAddress?
    ) throws -> Multistaking.OffchainResponse {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        return try performSubqueryStateFetch(
            for: substrateAddress,
            ethereumAddress: ethereumAddress,
            chainRegistry: chainRegistry
        )
    }

    private func performSubqueryStateFetch(
        for substrateAddress: AccountAddress,
        ethereumAddress: AccountAddress?,
        chainRegistry: ChainRegistryProtocol
    ) throws -> Multistaking.OffchainResponse {
        let substrateAccountId = try substrateAddress.toAccountId()
        let ethereumAccountId = try ethereumAddress?.toAccountId()

        let wallet = MetaAccountModel(
            metaId: UUID().uuidString,
            name: "test",
            substrateAccountId: substrateAccountId,
            substrateCryptoType: 0,
            substratePublicKey: substrateAccountId,
            ethereumAddress: ethereumAccountId,
            ethereumPublicKey: ethereumAccountId,
            chainAccounts: [],
            type: .watchOnly
        )

        let chainAssets = ChainsStore(chainRegistry: chainRegistry).getAllStakebleAssets()

        let operationFactory = SubqueryMultistakingOperationFactory(
            url: ApplicationConfig.shared.multistakingURL
        )

        let wrapper = operationFactory.createWrapper(
            from: wallet,
            resolvedAccounts: [:],
            chainAssets: chainAssets
        )

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
