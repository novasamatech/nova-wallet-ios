import XCTest
@testable import novawallet

final class DelegatedAccountsChangeCalculatorTests: XCTestCase {
    
    func testProxieAndUniversalMultisig() {
        // given
        
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0
        )
        
        let initialWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        
        let proxied = generateProxied(
            for: initialWallet.substrateAccountId!,
            chainId: chain.chainId,
            proxyType: .any
        )
        
        let multisig = generateMultisig(for: initialWallet.substrateAccountId!)
        
        let calculator = setupCalculator(chains: [chain])
        
        // when
        
        let changes = calculator.calculateUpdates(
            from: [proxied, multisig],
            initialMetaAccounts: [ManagedMetaAccountModel(info: initialWallet)],
            identities: [:]
        )
        
        // then
        
        guard changes.newOrUpdatedItems.count == 2 else {
            XCTFail("Expected 2 changes")
            return
        }
        
        XCTAssert(
            verifyProxy(
                wallet: changes.newOrUpdatedItems[0].info,
                proxiedModel: proxied
            )
        )
        
        XCTAssert(
            verifyMultisig(
                wallet: changes.newOrUpdatedItems[1].info,
                multisigModel: multisig,
                multisigType: .uniSubstrate
            )
        )
        
        XCTAssertEqual(changes.removedItems.count, 0)
    }
    
    func testProxyOfSignatory() {
        // given
        
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0
        )
        
        let initialWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        
        let proxied = generateProxied(
            for: initialWallet.substrateAccountId!,
            chainId: chain.chainId,
            proxyType: .any
        )
        
        let multisig = generateMultisig(for: proxied.accountId)
        
        let calculator = setupCalculator(chains: [chain])
        
        // when
        
        let changes = calculator.calculateUpdates(
            from: [proxied, multisig],
            initialMetaAccounts: [ManagedMetaAccountModel(info: initialWallet)],
            identities: [:]
        )
        
        // then
        
        guard changes.newOrUpdatedItems.count == 2 else {
            XCTFail("Expected 2 changes")
            return
        }
        
        XCTAssert(
            verifyProxy(
                wallet: changes.newOrUpdatedItems[0].info,
                proxiedModel: proxied
            )
        )
        
        XCTAssert(
            verifyMultisig(
                wallet: changes.newOrUpdatedItems[1].info,
                multisigModel: multisig,
                multisigType: .singleChain(chain.chainId)
            )
        )
        
        XCTAssertEqual(changes.removedItems.count, 0)
    }
    
    func testMultisigAsProxy() {
        // given
        
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0
        )
        
        let initialWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        
        let multisig = generateMultisig(for: initialWallet.substrateAccountId!)
        
        let proxied = generateProxied(
            for: multisig.accountId,
            chainId: chain.chainId,
            proxyType: .any
        )
        
        let calculator = setupCalculator(chains: [chain])
        
        // when
        
        let changes = calculator.calculateUpdates(
            from: [multisig, proxied],
            initialMetaAccounts: [ManagedMetaAccountModel(info: initialWallet)],
            identities: [:]
        )
        
        // then
        
        guard changes.newOrUpdatedItems.count == 2 else {
            XCTFail("Expected 2 changes")
            return
        }
        
        XCTAssert(
            verifyMultisig(
                wallet: changes.newOrUpdatedItems[0].info,
                multisigModel: multisig,
                multisigType: .uniSubstrate
            )
        )
        
        XCTAssert(
            verifyProxy(
                wallet: changes.newOrUpdatedItems[1].info,
                proxiedModel: proxied
            )
        )
        
        XCTAssertEqual(changes.removedItems.count, 0)
    }
    
    func testSingleChainMultisig() {
        // given
        
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0
        )
        
        let initialWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        
        let multisig = generateMultisig(for: initialWallet.substrateAccountId!)
        
        let calculator = setupCalculator(chains: [chain])
        
        // when
        
        let changes = calculator.calculateUpdates(
            from: [multisig],
            initialMetaAccounts: [ManagedMetaAccountModel(info: initialWallet)],
            identities: [:]
        )
        
        // then
        
        guard changes.newOrUpdatedItems.count == 1 else {
            XCTFail("Expected 2 changes")
            return
        }
        
        XCTAssert(
            verifyMultisig(
                wallet: changes.newOrUpdatedItems[0].info,
                multisigModel: multisig,
                multisigType: .singleChain(chain.chainId)
            )
        )
        
        XCTAssertEqual(changes.removedItems.count, 0)
    }
    
    func testMultisigNotDetectedForUnsupportedChain() {
        // given
        
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0,
            hasProxy: true,
            hasMultisig: false
        )
        
        let initialWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        
        let multisig = generateMultisig(for: initialWallet.substrateAccountId!)
        
        let calculator = setupCalculator(chains: [chain])
        
        // when
        
        let changes = calculator.calculateUpdates(
            from: [multisig],
            initialMetaAccounts: [ManagedMetaAccountModel(info: initialWallet)],
            identities: [:]
        )
        
        // then
        
        XCTAssertEqual(changes.newOrUpdatedItems.count, 0)
        XCTAssertEqual(changes.removedItems.count, 0)
    }
    
    func testProxyNotDetectedForUnsupportedChain() {
        // given
        
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0,
            hasProxy: false,
            hasMultisig: true
        )
        
        let initialWallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 0)
        
        let proxied = generateProxied(
            for: initialWallet.substrateAccountId!,
            chainId: chain.chainId,
            proxyType: .any
        )
        
        let calculator = setupCalculator(chains: [chain])
        
        // when
        
        let changes = calculator.calculateUpdates(
            from: [proxied],
            initialMetaAccounts: [ManagedMetaAccountModel(info: initialWallet)],
            identities: [:]
        )
        
        // then
        
        XCTAssertEqual(changes.newOrUpdatedItems.count, 0)
        XCTAssertEqual(changes.removedItems.count, 0)
    }
    
    func testMultisigNotDetectedForMissingSignatory() {
        // given
        
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0,
            hasProxy: true,
            hasMultisig: true
        )
        
        let initialWallet = AccountGenerator.generateMetaAccount()
        let otherWallet = AccountGenerator.generateMetaAccount()
        
        let multisig = generateMultisig(for: otherWallet.substrateAccountId!)
        
        let calculator = setupCalculator(chains: [chain])
        
        // when
        
        let changes = calculator.calculateUpdates(
            from: [multisig],
            initialMetaAccounts: [ManagedMetaAccountModel(info: initialWallet)],
            identities: [:]
        )
        
        // then
        
        XCTAssertEqual(changes.newOrUpdatedItems.count, 0)
        XCTAssertEqual(changes.removedItems.count, 0)
    }
    
    func testProxiedNotDetectedForMissingProxy() {
        // given
        
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0,
            hasProxy: true,
            hasMultisig: true
        )
        
        let initialWallet = AccountGenerator.generateMetaAccount()
        let otherWallet = AccountGenerator.generateMetaAccount()
        
        let proxied = generateProxied(
            for: otherWallet.substrateAccountId!,
            chainId: chain.chainId,
            proxyType: .any
        )
        
        let calculator = setupCalculator(chains: [chain])
        
        // when
        
        let changes = calculator.calculateUpdates(
            from: [proxied],
            initialMetaAccounts: [ManagedMetaAccountModel(info: initialWallet)],
            identities: [:]
        )
        
        // then
        
        XCTAssertEqual(changes.newOrUpdatedItems.count, 0)
        XCTAssertEqual(changes.removedItems.count, 0)
    }
    
    func testMultipleSingleChainsMultisigsForProxyAndWithSecretWallets() {
        // given
        
        let chain1 = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0,
            hasProxy: true,
            hasMultisig: true
        )
        
        let chain2 = ChainModelGenerator.generateChain(
            generatingAssets: 1,
            addressPrefix: 0,
            hasProxy: true,
            hasMultisig: true
        )
        
        let proxyWallet = AccountGenerator.generateMetaAccount()
        let normalWallet = AccountGenerator.generateMetaAccount()
        
        let proxied = DiscoveredAccount.ProxiedModel(
            proxyAccountId: proxyWallet.substrateAccountId!,
            proxiedAccountId: normalWallet.substrateAccountId!,
            type: .any,
            chainId: chain1.chainId
        )
        
        let multisig = generateMultisig(for: normalWallet.substrateAccountId!)
        
        let calculator = setupCalculator(chains: [chain1, chain2])
        
        // when
        
        let changes = calculator.calculateUpdates(
            from: [proxied, multisig],
            initialMetaAccounts: [
                ManagedMetaAccountModel(info: proxyWallet),
                ManagedMetaAccountModel(info: normalWallet)
            ],
            identities: [:]
        )
        
        // then
        
        guard changes.newOrUpdatedItems.count == 3 else {
            XCTFail("Expected 3 changes, got \(changes.newOrUpdatedItems.count)")
            return
        }
        
        XCTAssert(
            verifyProxy(
                wallet: changes.newOrUpdatedItems[0].info,
                proxiedModel: proxied
            )
        )
        
        XCTAssert(
            verifyMultisig(
                wallet: changes.newOrUpdatedItems[1].info,
                multisigModel: multisig,
                multisigType: .singleChain(chain1.chainId)
            )
        )
        
        XCTAssert(
            verifyMultisig(
                wallet: changes.newOrUpdatedItems[2].info,
                multisigModel: multisig,
                multisigType: .singleChain(chain2.chainId)
            )
        )
        
        XCTAssertEqual(changes.removedItems.count, 0)
    }
    
    private func verifyProxy(
        wallet: MetaAccountModel,
        proxiedModel: DiscoveredAccount.ProxiedModel
    ) -> Bool {
        guard let identifier = wallet.getDelegateIdentifier() else {
            return false
        }
        
        guard case .proxy = identifier.delegateType else {
            return false
        }
        
        return identifier.delegateAccountId == proxiedModel.delegateAccountId &&
            identifier.delegatorAccountId == proxiedModel.accountId &&
            identifier.chainId == proxiedModel.chainId
    }
    
    private func verifyMultisig(
        wallet: MetaAccountModel,
        multisigModel: DiscoveredAccount.MultisigModel,
        multisigType: DelegationType.MultisigModel
    ) -> Bool {
        guard let identifier = wallet.getDelegateIdentifier() else {
            return false
        }
        
        guard case let .multisig(typeModel) = identifier.delegateType else {
            return false
        }
        
        return identifier.delegateAccountId == multisigModel.signatory &&
            identifier.delegatorAccountId == multisigModel.accountId &&
            multisigType == typeModel
    }
    
    private func generateProxied(
        for proxyAccountId: AccountId,
        chainId: ChainModel.Id,
        proxyType: Proxy.ProxyType
    ) -> DiscoveredAccount.ProxiedModel {
        let proxiedAccountId = AccountId.random(of: 32)!
        
        return DiscoveredAccount.ProxiedModel(
            proxyAccountId: proxyAccountId,
            proxiedAccountId: proxiedAccountId,
            type: proxyType,
            chainId: chainId
        )
    }
    
    private func generateMultisig(
        for signatory: AccountId,
        threshold: Int = 2,
        totalSignatories: Int = 3
    ) -> DiscoveredAccount.MultisigModel {
        let signatories = (0..<totalSignatories - 1).map { _ in AccountId.random(of: 32)! }
        let multisigAccountId = AccountId.random(of: 32)!
        
        return DiscoveredAccount.MultisigModel(
            accountId: multisigAccountId,
            signatory: signatory,
            signatories: [signatory] + signatories,
            threshold: threshold
        )
    }
    
    private func setupCalculator(
        chains: Set<ChainModel>
    ) -> DelegatedAccountsChangesCalculatorProtocol {
        let chainRegistry = MockChainRegistryProtocol().applyDefault(for: chains)
        
        return DelegatedAccountsChangesCalculator(
            chainIds: Set(chains.map({ $0.chainId })),
            chainRegistry: chainRegistry,
            logger: Logger.shared
        )
    }
}
