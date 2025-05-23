import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation


public class MockKeystoreProtocol: KeystoreProtocol, Cuckoo.ProtocolMock {
    
    public typealias MocksType = KeystoreProtocol
    
    public typealias Stubbing = __StubbingProxy_KeystoreProtocol
    public typealias Verification = __VerificationProxy_KeystoreProtocol

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: KeystoreProtocol?

    public func enableDefaultImplementation(_ stub: KeystoreProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    public func addKey(_ key: Data, with identifier: String) throws {
        
    return try cuckoo_manager.callThrows("addKey(_: Data, with: String) throws",
            parameters: (key, identifier),
            escapingParameters: (key, identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.addKey(key, with: identifier))
        
    }
    
    
    
    public func updateKey(_ key: Data, with identifier: String) throws {
        
    return try cuckoo_manager.callThrows("updateKey(_: Data, with: String) throws",
            parameters: (key, identifier),
            escapingParameters: (key, identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateKey(key, with: identifier))
        
    }
    
    
    
    public func fetchKey(for identifier: String) throws -> Data {
        
    return try cuckoo_manager.callThrows("fetchKey(for: String) throws -> Data",
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchKey(for: identifier))
        
    }
    
    
    
    public func checkKey(for identifier: String) throws -> Bool {
        
    return try cuckoo_manager.callThrows("checkKey(for: String) throws -> Bool",
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.checkKey(for: identifier))
        
    }
    
    
    
    public func deleteKey(for identifier: String) throws {
        
    return try cuckoo_manager.callThrows("deleteKey(for: String) throws",
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.deleteKey(for: identifier))
        
    }
    

	public struct __StubbingProxy_KeystoreProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func addKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ key: M1, with identifier: M2) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(Data, String)> where M1.MatchedType == Data, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: key) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method: "addKey(_: Data, with: String) throws", parameterMatchers: matchers))
	    }
	    
	    func updateKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ key: M1, with identifier: M2) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(Data, String)> where M1.MatchedType == Data, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: key) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method: "updateKey(_: Data, with: String) throws", parameterMatchers: matchers))
	    }
	    
	    func fetchKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.ProtocolStubThrowingFunction<(String), Data> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method: "fetchKey(for: String) throws -> Data", parameterMatchers: matchers))
	    }
	    
	    func checkKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.ProtocolStubThrowingFunction<(String), Bool> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method: "checkKey(for: String) throws -> Bool", parameterMatchers: matchers))
	    }
	    
	    func deleteKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(String)> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockKeystoreProtocol.self, method: "deleteKey(for: String) throws", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_KeystoreProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func addKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ key: M1, with identifier: M2) -> Cuckoo.__DoNotUse<(Data, String), Void> where M1.MatchedType == Data, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: key) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
	        return cuckoo_manager.verify("addKey(_: Data, with: String) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func updateKey<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ key: M1, with identifier: M2) -> Cuckoo.__DoNotUse<(Data, String), Void> where M1.MatchedType == Data, M2.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(Data, String)>] = [wrap(matchable: key) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
	        return cuckoo_manager.verify("updateKey(_: Data, with: String) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.__DoNotUse<(String), Data> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return cuckoo_manager.verify("fetchKey(for: String) throws -> Data", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func checkKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.__DoNotUse<(String), Bool> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return cuckoo_manager.verify("checkKey(for: String) throws -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func deleteKey<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.__DoNotUse<(String), Void> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return cuckoo_manager.verify("deleteKey(for: String) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class KeystoreProtocolStub: KeystoreProtocol {
    

    

    
    
    
    public func addKey(_ key: Data, with identifier: String) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    public func updateKey(_ key: Data, with identifier: String) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    public func fetchKey(for identifier: String) throws -> Data  {
        return DefaultValueRegistry.defaultValue(for: (Data).self)
    }
    
    
    
    public func checkKey(for identifier: String) throws -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
    
    
    public func deleteKey(for identifier: String) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



public class MockSecretDataRepresentable: SecretDataRepresentable, Cuckoo.ProtocolMock {
    
    public typealias MocksType = SecretDataRepresentable
    
    public typealias Stubbing = __StubbingProxy_SecretDataRepresentable
    public typealias Verification = __VerificationProxy_SecretDataRepresentable

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SecretDataRepresentable?

    public func enableDefaultImplementation(_ stub: SecretDataRepresentable) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    public func asSecretData() -> Data? {
        
    return cuckoo_manager.call("asSecretData() -> Data?",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.asSecretData())
        
    }
    

	public struct __StubbingProxy_SecretDataRepresentable: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func asSecretData() -> Cuckoo.ProtocolStubFunction<(), Data?> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSecretDataRepresentable.self, method: "asSecretData() -> Data?", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_SecretDataRepresentable: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func asSecretData() -> Cuckoo.__DoNotUse<(), Data?> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("asSecretData() -> Data?", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class SecretDataRepresentableStub: SecretDataRepresentable {
    

    

    
    
    
    public func asSecretData() -> Data?  {
        return DefaultValueRegistry.defaultValue(for: (Data?).self)
    }
    
}



public class MockSecretStoreManagerProtocol: SecretStoreManagerProtocol, Cuckoo.ProtocolMock {
    
    public typealias MocksType = SecretStoreManagerProtocol
    
    public typealias Stubbing = __StubbingProxy_SecretStoreManagerProtocol
    public typealias Verification = __VerificationProxy_SecretStoreManagerProtocol

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SecretStoreManagerProtocol?

    public func enableDefaultImplementation(_ stub: SecretStoreManagerProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    public func loadSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)  {
        
    return cuckoo_manager.call("loadSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)",
            parameters: (identifier, completionQueue, completionBlock),
            escapingParameters: (identifier, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.loadSecret(for: identifier, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    
    
    public func saveSecret(_ secret: SecretDataRepresentable, for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("saveSecret(_: SecretDataRepresentable, for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
            parameters: (secret, identifier, completionQueue, completionBlock),
            escapingParameters: (secret, identifier, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.saveSecret(secret, for: identifier, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    
    
    public func removeSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("removeSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
            parameters: (identifier, completionQueue, completionBlock),
            escapingParameters: (identifier, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.removeSecret(for: identifier, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    
    
    public func checkSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("checkSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
            parameters: (identifier, completionQueue, completionBlock),
            escapingParameters: (identifier, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.checkSecret(for: identifier, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    
    
    
    public func checkSecret(for identifier: String) -> Bool {
        
    return cuckoo_manager.call("checkSecret(for: String) -> Bool",
            parameters: (identifier),
            escapingParameters: (identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.checkSecret(for: identifier))
        
    }
    

	public struct __StubbingProxy_SecretStoreManagerProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func loadSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue, (SecretDataRepresentable?) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (SecretDataRepresentable?) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (SecretDataRepresentable?) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method: "loadSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func saveSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(_ secret: M1, for identifier: M2, completionQueue: M3, completionBlock: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(SecretDataRepresentable, String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == SecretDataRepresentable, M2.MatchedType == String, M3.MatchedType == DispatchQueue, M4.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(SecretDataRepresentable, String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: secret) { $0.0 }, wrap(matchable: identifier) { $0.1 }, wrap(matchable: completionQueue) { $0.2 }, wrap(matchable: completionBlock) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method: "saveSecret(_: SecretDataRepresentable, for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func removeSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method: "removeSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func checkSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method: "checkSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func checkSecret<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.ProtocolStubFunction<(String), Bool> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSecretStoreManagerProtocol.self, method: "checkSecret(for: String) -> Bool", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_SecretStoreManagerProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func loadSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (SecretDataRepresentable?) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (SecretDataRepresentable?) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (SecretDataRepresentable?) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return cuckoo_manager.verify("loadSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func saveSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable>(_ secret: M1, for identifier: M2, completionQueue: M3, completionBlock: M4) -> Cuckoo.__DoNotUse<(SecretDataRepresentable, String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == SecretDataRepresentable, M2.MatchedType == String, M3.MatchedType == DispatchQueue, M4.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(SecretDataRepresentable, String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: secret) { $0.0 }, wrap(matchable: identifier) { $0.1 }, wrap(matchable: completionQueue) { $0.2 }, wrap(matchable: completionBlock) { $0.3 }]
	        return cuckoo_manager.verify("saveSecret(_: SecretDataRepresentable, for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func removeSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return cuckoo_manager.verify("removeSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func checkSecret<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for identifier: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: identifier) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return cuckoo_manager.verify("checkSecret(for: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func checkSecret<M1: Cuckoo.Matchable>(for identifier: M1) -> Cuckoo.__DoNotUse<(String), Bool> where M1.MatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String)>] = [wrap(matchable: identifier) { $0 }]
	        return cuckoo_manager.verify("checkSecret(for: String) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class SecretStoreManagerProtocolStub: SecretStoreManagerProtocol {
    

    

    
    
    
    public func loadSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    public func saveSecret(_ secret: SecretDataRepresentable, for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    public func removeSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    public func checkSecret(for identifier: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    public func checkSecret(for identifier: String) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation


public class MockJSONRPCResponseHandling: JSONRPCResponseHandling, Cuckoo.ProtocolMock {
    
    public typealias MocksType = JSONRPCResponseHandling
    
    public typealias Stubbing = __StubbingProxy_JSONRPCResponseHandling
    public typealias Verification = __VerificationProxy_JSONRPCResponseHandling

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: JSONRPCResponseHandling?

    public func enableDefaultImplementation(_ stub: JSONRPCResponseHandling) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    public func handle(data: Data, for identifier: UInt16)  {
        
    return cuckoo_manager.call("handle(data: Data, for: UInt16)",
            parameters: (data, identifier),
            escapingParameters: (data, identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(data: data, for: identifier))
        
    }
    
    
    
    public func handle(error: Error, for identifier: UInt16)  {
        
    return cuckoo_manager.call("handle(error: Error, for: UInt16)",
            parameters: (error, identifier),
            escapingParameters: (error, identifier),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(error: error, for: identifier))
        
    }
    

	public struct __StubbingProxy_JSONRPCResponseHandling: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func handle<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(data: M1, for identifier: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Data, UInt16)> where M1.MatchedType == Data, M2.MatchedType == UInt16 {
	        let matchers: [Cuckoo.ParameterMatcher<(Data, UInt16)>] = [wrap(matchable: data) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCResponseHandling.self, method: "handle(data: Data, for: UInt16)", parameterMatchers: matchers))
	    }
	    
	    func handle<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, for identifier: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Error, UInt16)> where M1.MatchedType == Error, M2.MatchedType == UInt16 {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, UInt16)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCResponseHandling.self, method: "handle(error: Error, for: UInt16)", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_JSONRPCResponseHandling: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func handle<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(data: M1, for identifier: M2) -> Cuckoo.__DoNotUse<(Data, UInt16), Void> where M1.MatchedType == Data, M2.MatchedType == UInt16 {
	        let matchers: [Cuckoo.ParameterMatcher<(Data, UInt16)>] = [wrap(matchable: data) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
	        return cuckoo_manager.verify("handle(data: Data, for: UInt16)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func handle<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, for identifier: M2) -> Cuckoo.__DoNotUse<(Error, UInt16), Void> where M1.MatchedType == Error, M2.MatchedType == UInt16 {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, UInt16)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: identifier) { $0.1 }]
	        return cuckoo_manager.verify("handle(error: Error, for: UInt16)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class JSONRPCResponseHandlingStub: JSONRPCResponseHandling {
    

    

    
    
    
    public func handle(data: Data, for identifier: UInt16)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    public func handle(error: Error, for identifier: UInt16)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



public class MockJSONRPCSubscribing: JSONRPCSubscribing, Cuckoo.ProtocolMock {
    
    public typealias MocksType = JSONRPCSubscribing
    
    public typealias Stubbing = __StubbingProxy_JSONRPCSubscribing
    public typealias Verification = __VerificationProxy_JSONRPCSubscribing

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: JSONRPCSubscribing?

    public func enableDefaultImplementation(_ stub: JSONRPCSubscribing) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
    public var requestId: UInt16 {
        get {
            return cuckoo_manager.getter("requestId",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.requestId)
        }
        
    }
    
    
    
    public var requestData: Data {
        get {
            return cuckoo_manager.getter("requestData",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.requestData)
        }
        
    }
    
    
    
    public var requestOptions: JSONRPCOptions {
        get {
            return cuckoo_manager.getter("requestOptions",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.requestOptions)
        }
        
    }
    
    
    
    public var remoteId: String? {
        get {
            return cuckoo_manager.getter("remoteId",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.remoteId)
        }
        
        set {
            cuckoo_manager.setter("remoteId",
                value: newValue,
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.remoteId = newValue)
        }
        
    }
    
    
    
    public var unsubscribeMethod: String {
        get {
            return cuckoo_manager.getter("unsubscribeMethod",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.unsubscribeMethod)
        }
        
    }
    

    

    
    
    
    public func handle(data: Data) throws {
        
    return try cuckoo_manager.callThrows("handle(data: Data) throws",
            parameters: (data),
            escapingParameters: (data),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(data: data))
        
    }
    
    
    
    public func handle(error: Error, unsubscribed: Bool)  {
        
    return cuckoo_manager.call("handle(error: Error, unsubscribed: Bool)",
            parameters: (error, unsubscribed),
            escapingParameters: (error, unsubscribed),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.handle(error: error, unsubscribed: unsubscribed))
        
    }
    

	public struct __StubbingProxy_JSONRPCSubscribing: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var requestId: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockJSONRPCSubscribing, UInt16> {
	        return .init(manager: cuckoo_manager, name: "requestId")
	    }
	    
	    
	    var requestData: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockJSONRPCSubscribing, Data> {
	        return .init(manager: cuckoo_manager, name: "requestData")
	    }
	    
	    
	    var requestOptions: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockJSONRPCSubscribing, JSONRPCOptions> {
	        return .init(manager: cuckoo_manager, name: "requestOptions")
	    }
	    
	    
	    var remoteId: Cuckoo.ProtocolToBeStubbedOptionalProperty<MockJSONRPCSubscribing, String> {
	        return .init(manager: cuckoo_manager, name: "remoteId")
	    }
	    
	    
	    var unsubscribeMethod: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockJSONRPCSubscribing, String> {
	        return .init(manager: cuckoo_manager, name: "unsubscribeMethod")
	    }
	    
	    
	    func handle<M1: Cuckoo.Matchable>(data: M1) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(Data)> where M1.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: data) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCSubscribing.self, method: "handle(data: Data) throws", parameterMatchers: matchers))
	    }
	    
	    func handle<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, unsubscribed: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(Error, Bool)> where M1.MatchedType == Error, M2.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, Bool)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: unsubscribed) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCSubscribing.self, method: "handle(error: Error, unsubscribed: Bool)", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_JSONRPCSubscribing: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var requestId: Cuckoo.VerifyReadOnlyProperty<UInt16> {
	        return .init(manager: cuckoo_manager, name: "requestId", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var requestData: Cuckoo.VerifyReadOnlyProperty<Data> {
	        return .init(manager: cuckoo_manager, name: "requestData", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var requestOptions: Cuckoo.VerifyReadOnlyProperty<JSONRPCOptions> {
	        return .init(manager: cuckoo_manager, name: "requestOptions", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var remoteId: Cuckoo.VerifyOptionalProperty<String> {
	        return .init(manager: cuckoo_manager, name: "remoteId", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var unsubscribeMethod: Cuckoo.VerifyReadOnlyProperty<String> {
	        return .init(manager: cuckoo_manager, name: "unsubscribeMethod", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func handle<M1: Cuckoo.Matchable>(data: M1) -> Cuckoo.__DoNotUse<(Data), Void> where M1.MatchedType == Data {
	        let matchers: [Cuckoo.ParameterMatcher<(Data)>] = [wrap(matchable: data) { $0 }]
	        return cuckoo_manager.verify("handle(data: Data) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func handle<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(error: M1, unsubscribed: M2) -> Cuckoo.__DoNotUse<(Error, Bool), Void> where M1.MatchedType == Error, M2.MatchedType == Bool {
	        let matchers: [Cuckoo.ParameterMatcher<(Error, Bool)>] = [wrap(matchable: error) { $0.0 }, wrap(matchable: unsubscribed) { $0.1 }]
	        return cuckoo_manager.verify("handle(error: Error, unsubscribed: Bool)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class JSONRPCSubscribingStub: JSONRPCSubscribing {
        
    
    
    public var requestId: UInt16 {
        get {
            return DefaultValueRegistry.defaultValue(for: (UInt16).self)
        }
        
    }
        
    
    
    public var requestData: Data {
        get {
            return DefaultValueRegistry.defaultValue(for: (Data).self)
        }
        
    }
        
    
    
    public var requestOptions: JSONRPCOptions {
        get {
            return DefaultValueRegistry.defaultValue(for: (JSONRPCOptions).self)
        }
        
    }
        
    
    
    public var remoteId: String? {
        get {
            return DefaultValueRegistry.defaultValue(for: (String?).self)
        }
        
        set { }
        
    }
        
    
    
    public var unsubscribeMethod: String {
        get {
            return DefaultValueRegistry.defaultValue(for: (String).self)
        }
        
    }
    

    

    
    
    
    public func handle(data: Data) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    public func handle(error: Error, unsubscribed: Bool)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



public class MockJSONRPCEngine: JSONRPCEngine, Cuckoo.ProtocolMock {
    
    public typealias MocksType = JSONRPCEngine
    
    public typealias Stubbing = __StubbingProxy_JSONRPCEngine
    public typealias Verification = __VerificationProxy_JSONRPCEngine

    public let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: JSONRPCEngine?

    public func enableDefaultImplementation(_ stub: JSONRPCEngine) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
    public func callMethod<P: Encodable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
        
    return try cuckoo_manager.callThrows("callMethod(_: String, params: P?, options: JSONRPCOptions, completion: ((Result<T, Error>) -> Void)?) throws -> UInt16",
            parameters: (method, params, options, closure),
            escapingParameters: (method, params, options, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.callMethod(method, params: params, options: options, completion: closure))
        
    }
    
    
    
    public func subscribe<P: Encodable, T: Decodable>(_ method: String, params: P?, unsubscribeMethod: String, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 {
        
    return try cuckoo_manager.callThrows("subscribe(_: String, params: P?, unsubscribeMethod: String, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16",
            parameters: (method, params, unsubscribeMethod, updateClosure, failureClosure),
            escapingParameters: (method, params, unsubscribeMethod, updateClosure, failureClosure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.subscribe(method, params: params, unsubscribeMethod: unsubscribeMethod, updateClosure: updateClosure, failureClosure: failureClosure))
        
    }
    
    
    
    public func cancelForIdentifiers(_ identifiers: [UInt16])  {
        
    return cuckoo_manager.call("cancelForIdentifiers(_: [UInt16])",
            parameters: (identifiers),
            escapingParameters: (identifiers),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.cancelForIdentifiers(identifiers))
        
    }
    
    
    
    public func addBatchCallMethod<P: Encodable>(_ method: String, params: P?, batchId: JSONRPCBatchId) throws {
        
    return try cuckoo_manager.callThrows("addBatchCallMethod(_: String, params: P?, batchId: JSONRPCBatchId) throws",
            parameters: (method, params, batchId),
            escapingParameters: (method, params, batchId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.addBatchCallMethod(method, params: params, batchId: batchId))
        
    }
    
    
    
    public func submitBatch(for batchId: JSONRPCBatchId, options: JSONRPCOptions, completion closure: (([Result<JSON, Error>]) -> Void)?) throws -> [UInt16] {
        
    return try cuckoo_manager.callThrows("submitBatch(for: JSONRPCBatchId, options: JSONRPCOptions, completion: (([Result<JSON, Error>]) -> Void)?) throws -> [UInt16]",
            parameters: (batchId, options, closure),
            escapingParameters: (batchId, options, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.submitBatch(for: batchId, options: options, completion: closure))
        
    }
    
    
    
    public func clearBatch(for batchId: JSONRPCBatchId)  {
        
    return cuckoo_manager.call("clearBatch(for: JSONRPCBatchId)",
            parameters: (batchId),
            escapingParameters: (batchId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.clearBatch(for: batchId))
        
    }
    

	public struct __StubbingProxy_JSONRPCEngine: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	    public init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func callMethod<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, P: Encodable, T: Decodable>(_ method: M1, params: M2, options: M3, completion closure: M4) -> Cuckoo.ProtocolStubThrowingFunction<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?), UInt16> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == JSONRPCOptions, M4.OptionalMatchedType == ((Result<T, Error>) -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: options) { $0.2 }, wrap(matchable: closure) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method: "callMethod(_: String, params: P?, options: JSONRPCOptions, completion: ((Result<T, Error>) -> Void)?) throws -> UInt16", parameterMatchers: matchers))
	    }
	    
	    func subscribe<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, M5: Cuckoo.Matchable, P: Encodable, T: Decodable>(_ method: M1, params: M2, unsubscribeMethod: M3, updateClosure: M4, failureClosure: M5) -> Cuckoo.ProtocolStubThrowingFunction<(String, P?, String, (T) -> Void, (Error, Bool) -> Void), UInt16> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == String, M4.MatchedType == (T) -> Void, M5.MatchedType == (Error, Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, P?, String, (T) -> Void, (Error, Bool) -> Void)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: unsubscribeMethod) { $0.2 }, wrap(matchable: updateClosure) { $0.3 }, wrap(matchable: failureClosure) { $0.4 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method: "subscribe(_: String, params: P?, unsubscribeMethod: String, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16", parameterMatchers: matchers))
	    }
	    
	    func cancelForIdentifiers<M1: Cuckoo.Matchable>(_ identifiers: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([UInt16])> where M1.MatchedType == [UInt16] {
	        let matchers: [Cuckoo.ParameterMatcher<([UInt16])>] = [wrap(matchable: identifiers) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method: "cancelForIdentifiers(_: [UInt16])", parameterMatchers: matchers))
	    }
	    
	    func addBatchCallMethod<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, P: Encodable>(_ method: M1, params: M2, batchId: M3) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(String, P?, JSONRPCBatchId)> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == JSONRPCBatchId {
	        let matchers: [Cuckoo.ParameterMatcher<(String, P?, JSONRPCBatchId)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: batchId) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method: "addBatchCallMethod(_: String, params: P?, batchId: JSONRPCBatchId) throws", parameterMatchers: matchers))
	    }
	    
	    func submitBatch<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(for batchId: M1, options: M2, completion closure: M3) -> Cuckoo.ProtocolStubThrowingFunction<(JSONRPCBatchId, JSONRPCOptions, (([Result<JSON, Error>]) -> Void)?), [UInt16]> where M1.MatchedType == JSONRPCBatchId, M2.MatchedType == JSONRPCOptions, M3.OptionalMatchedType == (([Result<JSON, Error>]) -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(JSONRPCBatchId, JSONRPCOptions, (([Result<JSON, Error>]) -> Void)?)>] = [wrap(matchable: batchId) { $0.0 }, wrap(matchable: options) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method: "submitBatch(for: JSONRPCBatchId, options: JSONRPCOptions, completion: (([Result<JSON, Error>]) -> Void)?) throws -> [UInt16]", parameterMatchers: matchers))
	    }
	    
	    func clearBatch<M1: Cuckoo.Matchable>(for batchId: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(JSONRPCBatchId)> where M1.MatchedType == JSONRPCBatchId {
	        let matchers: [Cuckoo.ParameterMatcher<(JSONRPCBatchId)>] = [wrap(matchable: batchId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockJSONRPCEngine.self, method: "clearBatch(for: JSONRPCBatchId)", parameterMatchers: matchers))
	    }
	    
	}

	public struct __VerificationProxy_JSONRPCEngine: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	    public init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func callMethod<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.OptionalMatchable, P: Encodable, T: Decodable>(_ method: M1, params: M2, options: M3, completion closure: M4) -> Cuckoo.__DoNotUse<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?), UInt16> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == JSONRPCOptions, M4.OptionalMatchedType == ((Result<T, Error>) -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(String, P?, JSONRPCOptions, ((Result<T, Error>) -> Void)?)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: options) { $0.2 }, wrap(matchable: closure) { $0.3 }]
	        return cuckoo_manager.verify("callMethod(_: String, params: P?, options: JSONRPCOptions, completion: ((Result<T, Error>) -> Void)?) throws -> UInt16", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func subscribe<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, M5: Cuckoo.Matchable, P: Encodable, T: Decodable>(_ method: M1, params: M2, unsubscribeMethod: M3, updateClosure: M4, failureClosure: M5) -> Cuckoo.__DoNotUse<(String, P?, String, (T) -> Void, (Error, Bool) -> Void), UInt16> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == String, M4.MatchedType == (T) -> Void, M5.MatchedType == (Error, Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, P?, String, (T) -> Void, (Error, Bool) -> Void)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: unsubscribeMethod) { $0.2 }, wrap(matchable: updateClosure) { $0.3 }, wrap(matchable: failureClosure) { $0.4 }]
	        return cuckoo_manager.verify("subscribe(_: String, params: P?, unsubscribeMethod: String, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func cancelForIdentifiers<M1: Cuckoo.Matchable>(_ identifiers: M1) -> Cuckoo.__DoNotUse<([UInt16]), Void> where M1.MatchedType == [UInt16] {
	        let matchers: [Cuckoo.ParameterMatcher<([UInt16])>] = [wrap(matchable: identifiers) { $0 }]
	        return cuckoo_manager.verify("cancelForIdentifiers(_: [UInt16])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func addBatchCallMethod<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.Matchable, P: Encodable>(_ method: M1, params: M2, batchId: M3) -> Cuckoo.__DoNotUse<(String, P?, JSONRPCBatchId), Void> where M1.MatchedType == String, M2.OptionalMatchedType == P, M3.MatchedType == JSONRPCBatchId {
	        let matchers: [Cuckoo.ParameterMatcher<(String, P?, JSONRPCBatchId)>] = [wrap(matchable: method) { $0.0 }, wrap(matchable: params) { $0.1 }, wrap(matchable: batchId) { $0.2 }]
	        return cuckoo_manager.verify("addBatchCallMethod(_: String, params: P?, batchId: JSONRPCBatchId) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func submitBatch<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(for batchId: M1, options: M2, completion closure: M3) -> Cuckoo.__DoNotUse<(JSONRPCBatchId, JSONRPCOptions, (([Result<JSON, Error>]) -> Void)?), [UInt16]> where M1.MatchedType == JSONRPCBatchId, M2.MatchedType == JSONRPCOptions, M3.OptionalMatchedType == (([Result<JSON, Error>]) -> Void) {
	        let matchers: [Cuckoo.ParameterMatcher<(JSONRPCBatchId, JSONRPCOptions, (([Result<JSON, Error>]) -> Void)?)>] = [wrap(matchable: batchId) { $0.0 }, wrap(matchable: options) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return cuckoo_manager.verify("submitBatch(for: JSONRPCBatchId, options: JSONRPCOptions, completion: (([Result<JSON, Error>]) -> Void)?) throws -> [UInt16]", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func clearBatch<M1: Cuckoo.Matchable>(for batchId: M1) -> Cuckoo.__DoNotUse<(JSONRPCBatchId), Void> where M1.MatchedType == JSONRPCBatchId {
	        let matchers: [Cuckoo.ParameterMatcher<(JSONRPCBatchId)>] = [wrap(matchable: batchId) { $0 }]
	        return cuckoo_manager.verify("clearBatch(for: JSONRPCBatchId)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

public class JSONRPCEngineStub: JSONRPCEngine {
    

    

    
    
    
    public func callMethod<P: Encodable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16  {
        return DefaultValueRegistry.defaultValue(for: (UInt16).self)
    }
    
    
    
    public func subscribe<P: Encodable, T: Decodable>(_ method: String, params: P?, unsubscribeMethod: String, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16  {
        return DefaultValueRegistry.defaultValue(for: (UInt16).self)
    }
    
    
    
    public func cancelForIdentifiers(_ identifiers: [UInt16])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    public func addBatchCallMethod<P: Encodable>(_ method: String, params: P?, batchId: JSONRPCBatchId) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
    public func submitBatch(for batchId: JSONRPCBatchId, options: JSONRPCOptions, completion closure: (([Result<JSON, Error>]) -> Void)?) throws -> [UInt16]  {
        return DefaultValueRegistry.defaultValue(for: ([UInt16]).self)
    }
    
    
    
    public func clearBatch(for batchId: JSONRPCBatchId)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Operation_iOS

import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation


 class MockEventProtocol: EventProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = EventProtocol
    
     typealias Stubbing = __StubbingProxy_EventProtocol
     typealias Verification = __VerificationProxy_EventProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: EventProtocol?

     func enableDefaultImplementation(_ stub: EventProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func accept(visitor: EventVisitorProtocol)  {
        
    return cuckoo_manager.call("accept(visitor: EventVisitorProtocol)",
            parameters: (visitor),
            escapingParameters: (visitor),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.accept(visitor: visitor))
        
    }
    

	 struct __StubbingProxy_EventProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func accept<M1: Cuckoo.Matchable>(visitor: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol)> where M1.MatchedType == EventVisitorProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: visitor) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventProtocol.self, method: "accept(visitor: EventVisitorProtocol)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_EventProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func accept<M1: Cuckoo.Matchable>(visitor: M1) -> Cuckoo.__DoNotUse<(EventVisitorProtocol), Void> where M1.MatchedType == EventVisitorProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: visitor) { $0 }]
	        return cuckoo_manager.verify("accept(visitor: EventVisitorProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class EventProtocolStub: EventProtocol {
    

    

    
    
    
     func accept(visitor: EventVisitorProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockEventCenterProtocol: EventCenterProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = EventCenterProtocol
    
     typealias Stubbing = __StubbingProxy_EventCenterProtocol
     typealias Verification = __VerificationProxy_EventCenterProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: EventCenterProtocol?

     func enableDefaultImplementation(_ stub: EventCenterProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func notify(with event: EventProtocol)  {
        
    return cuckoo_manager.call("notify(with: EventProtocol)",
            parameters: (event),
            escapingParameters: (event),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.notify(with: event))
        
    }
    
    
    
     func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?)  {
        
    return cuckoo_manager.call("add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)",
            parameters: (observer, queue),
            escapingParameters: (observer, queue),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.add(observer: observer, dispatchIn: queue))
        
    }
    
    
    
     func remove(observer: EventVisitorProtocol)  {
        
    return cuckoo_manager.call("remove(observer: EventVisitorProtocol)",
            parameters: (observer),
            escapingParameters: (observer),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.remove(observer: observer))
        
    }
    

	 struct __StubbingProxy_EventCenterProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func notify<M1: Cuckoo.Matchable>(with event: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventProtocol)> where M1.MatchedType == EventProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventProtocol)>] = [wrap(matchable: event) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method: "notify(with: EventProtocol)", parameterMatchers: matchers))
	    }
	    
	    func add<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(observer: M1, dispatchIn queue: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol, DispatchQueue?)> where M1.MatchedType == EventVisitorProtocol, M2.OptionalMatchedType == DispatchQueue {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol, DispatchQueue?)>] = [wrap(matchable: observer) { $0.0 }, wrap(matchable: queue) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method: "add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)", parameterMatchers: matchers))
	    }
	    
	    func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(EventVisitorProtocol)> where M1.MatchedType == EventVisitorProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: observer) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockEventCenterProtocol.self, method: "remove(observer: EventVisitorProtocol)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_EventCenterProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func notify<M1: Cuckoo.Matchable>(with event: M1) -> Cuckoo.__DoNotUse<(EventProtocol), Void> where M1.MatchedType == EventProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventProtocol)>] = [wrap(matchable: event) { $0 }]
	        return cuckoo_manager.verify("notify(with: EventProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func add<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(observer: M1, dispatchIn queue: M2) -> Cuckoo.__DoNotUse<(EventVisitorProtocol, DispatchQueue?), Void> where M1.MatchedType == EventVisitorProtocol, M2.OptionalMatchedType == DispatchQueue {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol, DispatchQueue?)>] = [wrap(matchable: observer) { $0.0 }, wrap(matchable: queue) { $0.1 }]
	        return cuckoo_manager.verify("add(observer: EventVisitorProtocol, dispatchIn: DispatchQueue?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func remove<M1: Cuckoo.Matchable>(observer: M1) -> Cuckoo.__DoNotUse<(EventVisitorProtocol), Void> where M1.MatchedType == EventVisitorProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(EventVisitorProtocol)>] = [wrap(matchable: observer) { $0 }]
	        return cuckoo_manager.verify("remove(observer: EventVisitorProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class EventCenterProtocolStub: EventCenterProtocol {
    

    

    
    
    
     func notify(with event: EventProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func add(observer: EventVisitorProtocol, dispatchIn queue: DispatchQueue?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func remove(observer: EventVisitorProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import NovaCrypto
import Operation_iOS


 class MockAccountRepositoryFactoryProtocol: AccountRepositoryFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = AccountRepositoryFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_AccountRepositoryFactoryProtocol
     typealias Verification = __VerificationProxy_AccountRepositoryFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: AccountRepositoryFactoryProtocol?

     func enableDefaultImplementation(_ stub: AccountRepositoryFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func createMetaAccountRepository(for filter: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel> {
        
    return cuckoo_manager.call("createMetaAccountRepository(for: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel>",
            parameters: (filter, sortDescriptors),
            escapingParameters: (filter, sortDescriptors),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createMetaAccountRepository(for: filter, sortDescriptors: sortDescriptors))
        
    }
    
    
    
     func createManagedMetaAccountRepository(for filter: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel> {
        
    return cuckoo_manager.call("createManagedMetaAccountRepository(for: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel>",
            parameters: (filter, sortDescriptors),
            escapingParameters: (filter, sortDescriptors),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createManagedMetaAccountRepository(for: filter, sortDescriptors: sortDescriptors))
        
    }
    
    
    
     func createFavoriteDAppsRepository() -> AnyDataProviderRepository<DAppFavorite> {
        
    return cuckoo_manager.call("createFavoriteDAppsRepository() -> AnyDataProviderRepository<DAppFavorite>",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createFavoriteDAppsRepository())
        
    }
    
    
    
     func createAuthorizedDAppsRepository(for metaId: String?) -> AnyDataProviderRepository<DAppSettings> {
        
    return cuckoo_manager.call("createAuthorizedDAppsRepository(for: String?) -> AnyDataProviderRepository<DAppSettings>",
            parameters: (metaId),
            escapingParameters: (metaId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createAuthorizedDAppsRepository(for: metaId))
        
    }
    
    
    
     func createDAppsGlobalSettingsRepository() -> AnyDataProviderRepository<DAppGlobalSettings> {
        
    return cuckoo_manager.call("createDAppsGlobalSettingsRepository() -> AnyDataProviderRepository<DAppGlobalSettings>",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createDAppsGlobalSettingsRepository())
        
    }
    
    
    
     func createProxiedSettingsRepository() -> AnyDataProviderRepository<ProxiedSettings> {
        
    return cuckoo_manager.call("createProxiedSettingsRepository() -> AnyDataProviderRepository<ProxiedSettings>",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createProxiedSettingsRepository())
        
    }
    

	 struct __StubbingProxy_AccountRepositoryFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func createMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for filter: M1, sortDescriptors: M2) -> Cuckoo.ProtocolStubFunction<(NSPredicate?, [NSSortDescriptor]), AnyDataProviderRepository<MetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
	        let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: filter) { $0.0 }, wrap(matchable: sortDescriptors) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self, method: "createMetaAccountRepository(for: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel>", parameterMatchers: matchers))
	    }
	    
	    func createManagedMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for filter: M1, sortDescriptors: M2) -> Cuckoo.ProtocolStubFunction<(NSPredicate?, [NSSortDescriptor]), AnyDataProviderRepository<ManagedMetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
	        let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: filter) { $0.0 }, wrap(matchable: sortDescriptors) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self, method: "createManagedMetaAccountRepository(for: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel>", parameterMatchers: matchers))
	    }
	    
	    func createFavoriteDAppsRepository() -> Cuckoo.ProtocolStubFunction<(), AnyDataProviderRepository<DAppFavorite>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self, method: "createFavoriteDAppsRepository() -> AnyDataProviderRepository<DAppFavorite>", parameterMatchers: matchers))
	    }
	    
	    func createAuthorizedDAppsRepository<M1: Cuckoo.OptionalMatchable>(for metaId: M1) -> Cuckoo.ProtocolStubFunction<(String?), AnyDataProviderRepository<DAppSettings>> where M1.OptionalMatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String?)>] = [wrap(matchable: metaId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self, method: "createAuthorizedDAppsRepository(for: String?) -> AnyDataProviderRepository<DAppSettings>", parameterMatchers: matchers))
	    }
	    
	    func createDAppsGlobalSettingsRepository() -> Cuckoo.ProtocolStubFunction<(), AnyDataProviderRepository<DAppGlobalSettings>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self, method: "createDAppsGlobalSettingsRepository() -> AnyDataProviderRepository<DAppGlobalSettings>", parameterMatchers: matchers))
	    }
	    
	    func createProxiedSettingsRepository() -> Cuckoo.ProtocolStubFunction<(), AnyDataProviderRepository<ProxiedSettings>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockAccountRepositoryFactoryProtocol.self, method: "createProxiedSettingsRepository() -> AnyDataProviderRepository<ProxiedSettings>", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_AccountRepositoryFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func createMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for filter: M1, sortDescriptors: M2) -> Cuckoo.__DoNotUse<(NSPredicate?, [NSSortDescriptor]), AnyDataProviderRepository<MetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
	        let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: filter) { $0.0 }, wrap(matchable: sortDescriptors) { $0.1 }]
	        return cuckoo_manager.verify("createMetaAccountRepository(for: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createManagedMetaAccountRepository<M1: Cuckoo.OptionalMatchable, M2: Cuckoo.Matchable>(for filter: M1, sortDescriptors: M2) -> Cuckoo.__DoNotUse<(NSPredicate?, [NSSortDescriptor]), AnyDataProviderRepository<ManagedMetaAccountModel>> where M1.OptionalMatchedType == NSPredicate, M2.MatchedType == [NSSortDescriptor] {
	        let matchers: [Cuckoo.ParameterMatcher<(NSPredicate?, [NSSortDescriptor])>] = [wrap(matchable: filter) { $0.0 }, wrap(matchable: sortDescriptors) { $0.1 }]
	        return cuckoo_manager.verify("createManagedMetaAccountRepository(for: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createFavoriteDAppsRepository() -> Cuckoo.__DoNotUse<(), AnyDataProviderRepository<DAppFavorite>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("createFavoriteDAppsRepository() -> AnyDataProviderRepository<DAppFavorite>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createAuthorizedDAppsRepository<M1: Cuckoo.OptionalMatchable>(for metaId: M1) -> Cuckoo.__DoNotUse<(String?), AnyDataProviderRepository<DAppSettings>> where M1.OptionalMatchedType == String {
	        let matchers: [Cuckoo.ParameterMatcher<(String?)>] = [wrap(matchable: metaId) { $0 }]
	        return cuckoo_manager.verify("createAuthorizedDAppsRepository(for: String?) -> AnyDataProviderRepository<DAppSettings>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createDAppsGlobalSettingsRepository() -> Cuckoo.__DoNotUse<(), AnyDataProviderRepository<DAppGlobalSettings>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("createDAppsGlobalSettingsRepository() -> AnyDataProviderRepository<DAppGlobalSettings>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createProxiedSettingsRepository() -> Cuckoo.__DoNotUse<(), AnyDataProviderRepository<ProxiedSettings>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("createProxiedSettingsRepository() -> AnyDataProviderRepository<ProxiedSettings>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class AccountRepositoryFactoryProtocolStub: AccountRepositoryFactoryProtocol {
    

    

    
    
    
     func createMetaAccountRepository(for filter: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<MetaAccountModel>  {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<MetaAccountModel>).self)
    }
    
    
    
     func createManagedMetaAccountRepository(for filter: NSPredicate?, sortDescriptors: [NSSortDescriptor]) -> AnyDataProviderRepository<ManagedMetaAccountModel>  {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<ManagedMetaAccountModel>).self)
    }
    
    
    
     func createFavoriteDAppsRepository() -> AnyDataProviderRepository<DAppFavorite>  {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<DAppFavorite>).self)
    }
    
    
    
     func createAuthorizedDAppsRepository(for metaId: String?) -> AnyDataProviderRepository<DAppSettings>  {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<DAppSettings>).self)
    }
    
    
    
     func createDAppsGlobalSettingsRepository() -> AnyDataProviderRepository<DAppGlobalSettings>  {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<DAppGlobalSettings>).self)
    }
    
    
    
     func createProxiedSettingsRepository() -> AnyDataProviderRepository<ProxiedSettings>  {
        return DefaultValueRegistry.defaultValue(for: (AnyDataProviderRepository<ProxiedSettings>).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation


 class MockSchedulerProtocol: SchedulerProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SchedulerProtocol
    
     typealias Stubbing = __StubbingProxy_SchedulerProtocol
     typealias Verification = __VerificationProxy_SchedulerProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SchedulerProtocol?

     func enableDefaultImplementation(_ stub: SchedulerProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var isScheduled: Bool {
        get {
            return cuckoo_manager.getter("isScheduled",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.isScheduled)
        }
        
    }
    

    

    
    
    
     func notifyAfter(_ seconds: TimeInterval)  {
        
    return cuckoo_manager.call("notifyAfter(_: TimeInterval)",
            parameters: (seconds),
            escapingParameters: (seconds),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.notifyAfter(seconds))
        
    }
    
    
    
     func cancel()  {
        
    return cuckoo_manager.call("cancel()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.cancel())
        
    }
    

	 struct __StubbingProxy_SchedulerProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isScheduled: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockSchedulerProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "isScheduled")
	    }
	    
	    
	    func notifyAfter<M1: Cuckoo.Matchable>(_ seconds: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(TimeInterval)> where M1.MatchedType == TimeInterval {
	        let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: seconds) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSchedulerProtocol.self, method: "notifyAfter(_: TimeInterval)", parameterMatchers: matchers))
	    }
	    
	    func cancel() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSchedulerProtocol.self, method: "cancel()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SchedulerProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isScheduled: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isScheduled", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func notifyAfter<M1: Cuckoo.Matchable>(_ seconds: M1) -> Cuckoo.__DoNotUse<(TimeInterval), Void> where M1.MatchedType == TimeInterval {
	        let matchers: [Cuckoo.ParameterMatcher<(TimeInterval)>] = [wrap(matchable: seconds) { $0 }]
	        return cuckoo_manager.verify("notifyAfter(_: TimeInterval)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func cancel() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("cancel()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SchedulerProtocolStub: SchedulerProtocol {
        
    
    
     var isScheduled: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
    
    
     func notifyAfter(_ seconds: TimeInterval)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func cancel()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockSchedulerDelegate: SchedulerDelegate, Cuckoo.ProtocolMock {
    
     typealias MocksType = SchedulerDelegate
    
     typealias Stubbing = __StubbingProxy_SchedulerDelegate
     typealias Verification = __VerificationProxy_SchedulerDelegate

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SchedulerDelegate?

     func enableDefaultImplementation(_ stub: SchedulerDelegate) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didTrigger(scheduler: SchedulerProtocol)  {
        
    return cuckoo_manager.call("didTrigger(scheduler: SchedulerProtocol)",
            parameters: (scheduler),
            escapingParameters: (scheduler),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didTrigger(scheduler: scheduler))
        
    }
    

	 struct __StubbingProxy_SchedulerDelegate: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didTrigger<M1: Cuckoo.Matchable>(scheduler: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(SchedulerProtocol)> where M1.MatchedType == SchedulerProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(SchedulerProtocol)>] = [wrap(matchable: scheduler) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSchedulerDelegate.self, method: "didTrigger(scheduler: SchedulerProtocol)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SchedulerDelegate: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didTrigger<M1: Cuckoo.Matchable>(scheduler: M1) -> Cuckoo.__DoNotUse<(SchedulerProtocol), Void> where M1.MatchedType == SchedulerProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(SchedulerProtocol)>] = [wrap(matchable: scheduler) { $0 }]
	        return cuckoo_manager.verify("didTrigger(scheduler: SchedulerProtocol)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SchedulerDelegateStub: SchedulerDelegate {
    

    

    
    
    
     func didTrigger(scheduler: SchedulerProtocol)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import LocalAuthentication
import UIKit.UIImage


 class MockBiometryAuthProtocol: BiometryAuthProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = BiometryAuthProtocol
    
     typealias Stubbing = __StubbingProxy_BiometryAuthProtocol
     typealias Verification = __VerificationProxy_BiometryAuthProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: BiometryAuthProtocol?

     func enableDefaultImplementation(_ stub: BiometryAuthProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var availableBiometryType: AvailableBiometryType {
        get {
            return cuckoo_manager.getter("availableBiometryType",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.availableBiometryType)
        }
        
    }
    
    
    
     var supportedBiometryType: AvailableBiometryType {
        get {
            return cuckoo_manager.getter("supportedBiometryType",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.supportedBiometryType)
        }
        
    }
    

    

    
    
    
     func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
            parameters: (localizedReason, completionQueue, completionBlock),
            escapingParameters: (localizedReason, completionQueue, completionBlock),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.authenticate(localizedReason: localizedReason, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    

	 struct __StubbingProxy_BiometryAuthProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var availableBiometryType: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockBiometryAuthProtocol, AvailableBiometryType> {
	        return .init(manager: cuckoo_manager, name: "availableBiometryType")
	    }
	    
	    
	    var supportedBiometryType: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockBiometryAuthProtocol, AvailableBiometryType> {
	        return .init(manager: cuckoo_manager, name: "supportedBiometryType")
	    }
	    
	    
	    func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: localizedReason) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockBiometryAuthProtocol.self, method: "authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_BiometryAuthProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var availableBiometryType: Cuckoo.VerifyReadOnlyProperty<AvailableBiometryType> {
	        return .init(manager: cuckoo_manager, name: "availableBiometryType", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var supportedBiometryType: Cuckoo.VerifyReadOnlyProperty<AvailableBiometryType> {
	        return .init(manager: cuckoo_manager, name: "supportedBiometryType", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: localizedReason) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return cuckoo_manager.verify("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class BiometryAuthProtocolStub: BiometryAuthProtocol {
        
    
    
     var availableBiometryType: AvailableBiometryType {
        get {
            return DefaultValueRegistry.defaultValue(for: (AvailableBiometryType).self)
        }
        
    }
        
    
    
     var supportedBiometryType: AvailableBiometryType {
        get {
            return DefaultValueRegistry.defaultValue(for: (AvailableBiometryType).self)
        }
        
    }
    

    

    
    
    
     func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockBiometryAuth: BiometryAuth, Cuckoo.ClassMock {
    
     typealias MocksType = BiometryAuth
    
     typealias Stubbing = __StubbingProxy_BiometryAuth
     typealias Verification = __VerificationProxy_BiometryAuth

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    
    private var __defaultImplStub: BiometryAuth?

     func enableDefaultImplementation(_ stub: BiometryAuth) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     override var availableBiometryType: AvailableBiometryType {
        get {
            return cuckoo_manager.getter("availableBiometryType",
                superclassCall:
                    
                    super.availableBiometryType
                    ,
                defaultCall: __defaultImplStub!.availableBiometryType)
        }
        
    }
    
    
    
     override var supportedBiometryType: AvailableBiometryType {
        get {
            return cuckoo_manager.getter("supportedBiometryType",
                superclassCall:
                    
                    super.supportedBiometryType
                    ,
                defaultCall: __defaultImplStub!.supportedBiometryType)
        }
        
    }
    

    

    
    
    
     override func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)  {
        
    return cuckoo_manager.call("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)",
            parameters: (localizedReason, completionQueue, completionBlock),
            escapingParameters: (localizedReason, completionQueue, completionBlock),
            superclassCall:
                
                super.authenticate(localizedReason: localizedReason, completionQueue: completionQueue, completionBlock: completionBlock)
                ,
            defaultCall: __defaultImplStub!.authenticate(localizedReason: localizedReason, completionQueue: completionQueue, completionBlock: completionBlock))
        
    }
    

	 struct __StubbingProxy_BiometryAuth: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var availableBiometryType: Cuckoo.ClassToBeStubbedReadOnlyProperty<MockBiometryAuth, AvailableBiometryType> {
	        return .init(manager: cuckoo_manager, name: "availableBiometryType")
	    }
	    
	    
	    var supportedBiometryType: Cuckoo.ClassToBeStubbedReadOnlyProperty<MockBiometryAuth, AvailableBiometryType> {
	        return .init(manager: cuckoo_manager, name: "supportedBiometryType")
	    }
	    
	    
	    func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.ClassStubNoReturnFunction<(String, DispatchQueue, (Bool) -> Void)> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: localizedReason) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockBiometryAuth.self, method: "authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_BiometryAuth: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var availableBiometryType: Cuckoo.VerifyReadOnlyProperty<AvailableBiometryType> {
	        return .init(manager: cuckoo_manager, name: "availableBiometryType", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var supportedBiometryType: Cuckoo.VerifyReadOnlyProperty<AvailableBiometryType> {
	        return .init(manager: cuckoo_manager, name: "supportedBiometryType", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func authenticate<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(localizedReason: M1, completionQueue: M2, completionBlock: M3) -> Cuckoo.__DoNotUse<(String, DispatchQueue, (Bool) -> Void), Void> where M1.MatchedType == String, M2.MatchedType == DispatchQueue, M3.MatchedType == (Bool) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(String, DispatchQueue, (Bool) -> Void)>] = [wrap(matchable: localizedReason) { $0.0 }, wrap(matchable: completionQueue) { $0.1 }, wrap(matchable: completionBlock) { $0.2 }]
	        return cuckoo_manager.verify("authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class BiometryAuthStub: BiometryAuth {
        
    
    
     override var availableBiometryType: AvailableBiometryType {
        get {
            return DefaultValueRegistry.defaultValue(for: (AvailableBiometryType).self)
        }
        
    }
        
    
    
     override var supportedBiometryType: AvailableBiometryType {
        get {
            return DefaultValueRegistry.defaultValue(for: (AvailableBiometryType).self)
        }
        
    }
    

    

    
    
    
     override func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation


 class MockConnectionAutobalancing: ConnectionAutobalancing, Cuckoo.ProtocolMock {
    
     typealias MocksType = ConnectionAutobalancing
    
     typealias Stubbing = __StubbingProxy_ConnectionAutobalancing
     typealias Verification = __VerificationProxy_ConnectionAutobalancing

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ConnectionAutobalancing?

     func enableDefaultImplementation(_ stub: ConnectionAutobalancing) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var urls: [URL] {
        get {
            return cuckoo_manager.getter("urls",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.urls)
        }
        
    }
    

    

    
    
    
     func changeUrls(_ newUrls: [URL])  {
        
    return cuckoo_manager.call("changeUrls(_: [URL])",
            parameters: (newUrls),
            escapingParameters: (newUrls),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.changeUrls(newUrls))
        
    }
    

	 struct __StubbingProxy_ConnectionAutobalancing: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var urls: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockConnectionAutobalancing, [URL]> {
	        return .init(manager: cuckoo_manager, name: "urls")
	    }
	    
	    
	    func changeUrls<M1: Cuckoo.Matchable>(_ newUrls: M1) -> Cuckoo.ProtocolStubNoReturnFunction<([URL])> where M1.MatchedType == [URL] {
	        let matchers: [Cuckoo.ParameterMatcher<([URL])>] = [wrap(matchable: newUrls) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionAutobalancing.self, method: "changeUrls(_: [URL])", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ConnectionAutobalancing: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var urls: Cuckoo.VerifyReadOnlyProperty<[URL]> {
	        return .init(manager: cuckoo_manager, name: "urls", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func changeUrls<M1: Cuckoo.Matchable>(_ newUrls: M1) -> Cuckoo.__DoNotUse<([URL]), Void> where M1.MatchedType == [URL] {
	        let matchers: [Cuckoo.ParameterMatcher<([URL])>] = [wrap(matchable: newUrls) { $0 }]
	        return cuckoo_manager.verify("changeUrls(_: [URL])", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ConnectionAutobalancingStub: ConnectionAutobalancing {
        
    
    
     var urls: [URL] {
        get {
            return DefaultValueRegistry.defaultValue(for: ([URL]).self)
        }
        
    }
    

    

    
    
    
     func changeUrls(_ newUrls: [URL])   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import SubstrateSdk


 class MockConnectionStateReporting: ConnectionStateReporting, Cuckoo.ProtocolMock {
    
     typealias MocksType = ConnectionStateReporting
    
     typealias Stubbing = __StubbingProxy_ConnectionStateReporting
     typealias Verification = __VerificationProxy_ConnectionStateReporting

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ConnectionStateReporting?

     func enableDefaultImplementation(_ stub: ConnectionStateReporting) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var state: WebSocketEngine.State {
        get {
            return cuckoo_manager.getter("state",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.state)
        }
        
    }
    

    

    

	 struct __StubbingProxy_ConnectionStateReporting: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var state: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockConnectionStateReporting, WebSocketEngine.State> {
	        return .init(manager: cuckoo_manager, name: "state")
	    }
	    
	    
	}

	 struct __VerificationProxy_ConnectionStateReporting: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var state: Cuckoo.VerifyReadOnlyProperty<WebSocketEngine.State> {
	        return .init(manager: cuckoo_manager, name: "state", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

 class ConnectionStateReportingStub: ConnectionStateReporting {
        
    
    
     var state: WebSocketEngine.State {
        get {
            return DefaultValueRegistry.defaultValue(for: (WebSocketEngine.State).self)
        }
        
    }
    

    

    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Operation_iOS


 class MockDataOperationFactoryProtocol: DataOperationFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = DataOperationFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_DataOperationFactoryProtocol
     typealias Verification = __VerificationProxy_DataOperationFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: DataOperationFactoryProtocol?

     func enableDefaultImplementation(_ stub: DataOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func fetchData(from url: URL) -> BaseOperation<Data> {
        
    return cuckoo_manager.call("fetchData(from: URL) -> BaseOperation<Data>",
            parameters: (url),
            escapingParameters: (url),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchData(from: url))
        
    }
    

	 struct __StubbingProxy_DataOperationFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func fetchData<M1: Cuckoo.Matchable>(from url: M1) -> Cuckoo.ProtocolStubFunction<(URL), BaseOperation<Data>> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockDataOperationFactoryProtocol.self, method: "fetchData(from: URL) -> BaseOperation<Data>", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_DataOperationFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func fetchData<M1: Cuckoo.Matchable>(from url: M1) -> Cuckoo.__DoNotUse<(URL), BaseOperation<Data>> where M1.MatchedType == URL {
	        let matchers: [Cuckoo.ParameterMatcher<(URL)>] = [wrap(matchable: url) { $0 }]
	        return cuckoo_manager.verify("fetchData(from: URL) -> BaseOperation<Data>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class DataOperationFactoryProtocolStub: DataOperationFactoryProtocol {
    

    

    
    
    
     func fetchData(from url: URL) -> BaseOperation<Data>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<Data>).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Operation_iOS
import SubstrateSdk


 class MockChainRegistryProtocol: ChainRegistryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ChainRegistryProtocol
    
     typealias Stubbing = __StubbingProxy_ChainRegistryProtocol
     typealias Verification = __VerificationProxy_ChainRegistryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ChainRegistryProtocol?

     func enableDefaultImplementation(_ stub: ChainRegistryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var availableChainIds: Set<ChainModel.Id>? {
        get {
            return cuckoo_manager.getter("availableChainIds",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.availableChainIds)
        }
        
    }
    

    

    
    
    
     func getChain(for chainId: ChainModel.Id) -> ChainModel? {
        
    return cuckoo_manager.call("getChain(for: ChainModel.Id) -> ChainModel?",
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.getChain(for: chainId))
        
    }
    
    
    
     func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        
    return cuckoo_manager.call("getConnection(for: ChainModel.Id) -> ChainConnection?",
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.getConnection(for: chainId))
        
    }
    
    
    
     func getOneShotConnection(for chainId: ChainModel.Id) -> JSONRPCEngine? {
        
    return cuckoo_manager.call("getOneShotConnection(for: ChainModel.Id) -> JSONRPCEngine?",
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.getOneShotConnection(for: chainId))
        
    }
    
    
    
     func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        
    return cuckoo_manager.call("getRuntimeProvider(for: ChainModel.Id) -> RuntimeProviderProtocol?",
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.getRuntimeProvider(for: chainId))
        
    }
    
    
    
     func switchSync(mode: ChainSyncMode, chainId: ChainModel.Id) throws {
        
    return try cuckoo_manager.callThrows("switchSync(mode: ChainSyncMode, chainId: ChainModel.Id) throws",
            parameters: (mode, chainId),
            escapingParameters: (mode, chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.switchSync(mode: mode, chainId: chainId))
        
    }
    
    
    
     func chainsSubscribe(_ target: AnyObject, runningInQueue: DispatchQueue, filterStrategy: ChainFilterStrategy?, updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void)  {
        
    return cuckoo_manager.call("chainsSubscribe(_: AnyObject, runningInQueue: DispatchQueue, filterStrategy: ChainFilterStrategy?, updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void)",
            parameters: (target, runningInQueue, filterStrategy, updateClosure),
            escapingParameters: (target, runningInQueue, filterStrategy, updateClosure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.chainsSubscribe(target, runningInQueue: runningInQueue, filterStrategy: filterStrategy, updateClosure: updateClosure))
        
    }
    
    
    
     func chainsUnsubscribe(_ target: AnyObject)  {
        
    return cuckoo_manager.call("chainsUnsubscribe(_: AnyObject)",
            parameters: (target),
            escapingParameters: (target),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.chainsUnsubscribe(target))
        
    }
    
    
    
     func subscribeChainState(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call("subscribeChainState(_: ConnectionStateSubscription, chainId: ChainModel.Id)",
            parameters: (subscriber, chainId),
            escapingParameters: (subscriber, chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.subscribeChainState(subscriber, chainId: chainId))
        
    }
    
    
    
     func unsubscribeChainState(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call("unsubscribeChainState(_: ConnectionStateSubscription, chainId: ChainModel.Id)",
            parameters: (subscriber, chainId),
            escapingParameters: (subscriber, chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.unsubscribeChainState(subscriber, chainId: chainId))
        
    }
    
    
    
     func syncUp()  {
        
    return cuckoo_manager.call("syncUp()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.syncUp())
        
    }
    

	 struct __StubbingProxy_ChainRegistryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var availableChainIds: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockChainRegistryProtocol, Set<ChainModel.Id>?> {
	        return .init(manager: cuckoo_manager, name: "availableChainIds")
	    }
	    
	    
	    func getChain<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), ChainModel?> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method: "getChain(for: ChainModel.Id) -> ChainModel?", parameterMatchers: matchers))
	    }
	    
	    func getConnection<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), ChainConnection?> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method: "getConnection(for: ChainModel.Id) -> ChainConnection?", parameterMatchers: matchers))
	    }
	    
	    func getOneShotConnection<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), JSONRPCEngine?> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method: "getOneShotConnection(for: ChainModel.Id) -> JSONRPCEngine?", parameterMatchers: matchers))
	    }
	    
	    func getRuntimeProvider<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), RuntimeProviderProtocol?> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method: "getRuntimeProvider(for: ChainModel.Id) -> RuntimeProviderProtocol?", parameterMatchers: matchers))
	    }
	    
	    func switchSync<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(mode: M1, chainId: M2) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(ChainSyncMode, ChainModel.Id)> where M1.MatchedType == ChainSyncMode, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainSyncMode, ChainModel.Id)>] = [wrap(matchable: mode) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method: "switchSync(mode: ChainSyncMode, chainId: ChainModel.Id) throws", parameterMatchers: matchers))
	    }
	    
	    func chainsSubscribe<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.Matchable>(_ target: M1, runningInQueue: M2, filterStrategy: M3, updateClosure: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(AnyObject, DispatchQueue, ChainFilterStrategy?, ([DataProviderChange<ChainModel>]) -> Void)> where M1.MatchedType == AnyObject, M2.MatchedType == DispatchQueue, M3.OptionalMatchedType == ChainFilterStrategy, M4.MatchedType == ([DataProviderChange<ChainModel>]) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(AnyObject, DispatchQueue, ChainFilterStrategy?, ([DataProviderChange<ChainModel>]) -> Void)>] = [wrap(matchable: target) { $0.0 }, wrap(matchable: runningInQueue) { $0.1 }, wrap(matchable: filterStrategy) { $0.2 }, wrap(matchable: updateClosure) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method: "chainsSubscribe(_: AnyObject, runningInQueue: DispatchQueue, filterStrategy: ChainFilterStrategy?, updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void)", parameterMatchers: matchers))
	    }
	    
	    func chainsUnsubscribe<M1: Cuckoo.Matchable>(_ target: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(AnyObject)> where M1.MatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AnyObject)>] = [wrap(matchable: target) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method: "chainsUnsubscribe(_: AnyObject)", parameterMatchers: matchers))
	    }
	    
	    func subscribeChainState<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ subscriber: M1, chainId: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionStateSubscription, ChainModel.Id)> where M1.MatchedType == ConnectionStateSubscription, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionStateSubscription, ChainModel.Id)>] = [wrap(matchable: subscriber) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method: "subscribeChainState(_: ConnectionStateSubscription, chainId: ChainModel.Id)", parameterMatchers: matchers))
	    }
	    
	    func unsubscribeChainState<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ subscriber: M1, chainId: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionStateSubscription, ChainModel.Id)> where M1.MatchedType == ConnectionStateSubscription, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionStateSubscription, ChainModel.Id)>] = [wrap(matchable: subscriber) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method: "unsubscribeChainState(_: ConnectionStateSubscription, chainId: ChainModel.Id)", parameterMatchers: matchers))
	    }
	    
	    func syncUp() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockChainRegistryProtocol.self, method: "syncUp()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ChainRegistryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var availableChainIds: Cuckoo.VerifyReadOnlyProperty<Set<ChainModel.Id>?> {
	        return .init(manager: cuckoo_manager, name: "availableChainIds", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func getChain<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), ChainModel?> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return cuckoo_manager.verify("getChain(for: ChainModel.Id) -> ChainModel?", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func getConnection<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), ChainConnection?> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return cuckoo_manager.verify("getConnection(for: ChainModel.Id) -> ChainConnection?", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func getOneShotConnection<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), JSONRPCEngine?> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return cuckoo_manager.verify("getOneShotConnection(for: ChainModel.Id) -> JSONRPCEngine?", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func getRuntimeProvider<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), RuntimeProviderProtocol?> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return cuckoo_manager.verify("getRuntimeProvider(for: ChainModel.Id) -> RuntimeProviderProtocol?", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func switchSync<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(mode: M1, chainId: M2) -> Cuckoo.__DoNotUse<(ChainSyncMode, ChainModel.Id), Void> where M1.MatchedType == ChainSyncMode, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainSyncMode, ChainModel.Id)>] = [wrap(matchable: mode) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return cuckoo_manager.verify("switchSync(mode: ChainSyncMode, chainId: ChainModel.Id) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func chainsSubscribe<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.Matchable>(_ target: M1, runningInQueue: M2, filterStrategy: M3, updateClosure: M4) -> Cuckoo.__DoNotUse<(AnyObject, DispatchQueue, ChainFilterStrategy?, ([DataProviderChange<ChainModel>]) -> Void), Void> where M1.MatchedType == AnyObject, M2.MatchedType == DispatchQueue, M3.OptionalMatchedType == ChainFilterStrategy, M4.MatchedType == ([DataProviderChange<ChainModel>]) -> Void {
	        let matchers: [Cuckoo.ParameterMatcher<(AnyObject, DispatchQueue, ChainFilterStrategy?, ([DataProviderChange<ChainModel>]) -> Void)>] = [wrap(matchable: target) { $0.0 }, wrap(matchable: runningInQueue) { $0.1 }, wrap(matchable: filterStrategy) { $0.2 }, wrap(matchable: updateClosure) { $0.3 }]
	        return cuckoo_manager.verify("chainsSubscribe(_: AnyObject, runningInQueue: DispatchQueue, filterStrategy: ChainFilterStrategy?, updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func chainsUnsubscribe<M1: Cuckoo.Matchable>(_ target: M1) -> Cuckoo.__DoNotUse<(AnyObject), Void> where M1.MatchedType == AnyObject {
	        let matchers: [Cuckoo.ParameterMatcher<(AnyObject)>] = [wrap(matchable: target) { $0 }]
	        return cuckoo_manager.verify("chainsUnsubscribe(_: AnyObject)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func subscribeChainState<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ subscriber: M1, chainId: M2) -> Cuckoo.__DoNotUse<(ConnectionStateSubscription, ChainModel.Id), Void> where M1.MatchedType == ConnectionStateSubscription, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionStateSubscription, ChainModel.Id)>] = [wrap(matchable: subscriber) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return cuckoo_manager.verify("subscribeChainState(_: ConnectionStateSubscription, chainId: ChainModel.Id)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func unsubscribeChainState<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ subscriber: M1, chainId: M2) -> Cuckoo.__DoNotUse<(ConnectionStateSubscription, ChainModel.Id), Void> where M1.MatchedType == ConnectionStateSubscription, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionStateSubscription, ChainModel.Id)>] = [wrap(matchable: subscriber) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return cuckoo_manager.verify("unsubscribeChainState(_: ConnectionStateSubscription, chainId: ChainModel.Id)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func syncUp() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("syncUp()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ChainRegistryProtocolStub: ChainRegistryProtocol {
        
    
    
     var availableChainIds: Set<ChainModel.Id>? {
        get {
            return DefaultValueRegistry.defaultValue(for: (Set<ChainModel.Id>?).self)
        }
        
    }
    

    

    
    
    
     func getChain(for chainId: ChainModel.Id) -> ChainModel?  {
        return DefaultValueRegistry.defaultValue(for: (ChainModel?).self)
    }
    
    
    
     func getConnection(for chainId: ChainModel.Id) -> ChainConnection?  {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection?).self)
    }
    
    
    
     func getOneShotConnection(for chainId: ChainModel.Id) -> JSONRPCEngine?  {
        return DefaultValueRegistry.defaultValue(for: (JSONRPCEngine?).self)
    }
    
    
    
     func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?  {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol?).self)
    }
    
    
    
     func switchSync(mode: ChainSyncMode, chainId: ChainModel.Id) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func chainsSubscribe(_ target: AnyObject, runningInQueue: DispatchQueue, filterStrategy: ChainFilterStrategy?, updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func chainsUnsubscribe(_ target: AnyObject)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func subscribeChainState(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func unsubscribeChainState(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func syncUp()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Foundation_iOS
import SubstrateSdk


 class MockConnectionFactoryProtocol: ConnectionFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ConnectionFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_ConnectionFactoryProtocol
     typealias Verification = __VerificationProxy_ConnectionFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ConnectionFactoryProtocol?

     func enableDefaultImplementation(_ stub: ConnectionFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func createConnection(for chain: ChainNodeConnectable, delegate: WebSocketEngineDelegate?) throws -> ChainConnection {
        
    return try cuckoo_manager.callThrows("createConnection(for: ChainNodeConnectable, delegate: WebSocketEngineDelegate?) throws -> ChainConnection",
            parameters: (chain, delegate),
            escapingParameters: (chain, delegate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createConnection(for: chain, delegate: delegate))
        
    }
    
    
    
     func createConnection(for node: ChainNodeModel, chain: ChainNodeConnectable, delegate: WebSocketEngineDelegate?) throws -> ChainConnection {
        
    return try cuckoo_manager.callThrows("createConnection(for: ChainNodeModel, chain: ChainNodeConnectable, delegate: WebSocketEngineDelegate?) throws -> ChainConnection",
            parameters: (node, chain, delegate),
            escapingParameters: (node, chain, delegate),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createConnection(for: node, chain: chain, delegate: delegate))
        
    }
    
    
    
     func updateConnection(_ connection: ChainConnection, chain: ChainNodeConnectable)  {
        
    return cuckoo_manager.call("updateConnection(_: ChainConnection, chain: ChainNodeConnectable)",
            parameters: (connection, chain),
            escapingParameters: (connection, chain),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateConnection(connection, chain: chain))
        
    }
    
    
    
     func updateOneShotConnection(_ connection: OneShotConnection, chain: ChainNodeConnectable)  {
        
    return cuckoo_manager.call("updateOneShotConnection(_: OneShotConnection, chain: ChainNodeConnectable)",
            parameters: (connection, chain),
            escapingParameters: (connection, chain),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.updateOneShotConnection(connection, chain: chain))
        
    }
    
    
    
     func createOneShotConnection(for chain: ChainNodeConnectable) throws -> OneShotConnection {
        
    return try cuckoo_manager.callThrows("createOneShotConnection(for: ChainNodeConnectable) throws -> OneShotConnection",
            parameters: (chain),
            escapingParameters: (chain),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createOneShotConnection(for: chain))
        
    }
    

	 struct __StubbingProxy_ConnectionFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func createConnection<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for chain: M1, delegate: M2) -> Cuckoo.ProtocolStubThrowingFunction<(ChainNodeConnectable, WebSocketEngineDelegate?), ChainConnection> where M1.MatchedType == ChainNodeConnectable, M2.OptionalMatchedType == WebSocketEngineDelegate {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainNodeConnectable, WebSocketEngineDelegate?)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: delegate) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionFactoryProtocol.self, method: "createConnection(for: ChainNodeConnectable, delegate: WebSocketEngineDelegate?) throws -> ChainConnection", parameterMatchers: matchers))
	    }
	    
	    func createConnection<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(for node: M1, chain: M2, delegate: M3) -> Cuckoo.ProtocolStubThrowingFunction<(ChainNodeModel, ChainNodeConnectable, WebSocketEngineDelegate?), ChainConnection> where M1.MatchedType == ChainNodeModel, M2.MatchedType == ChainNodeConnectable, M3.OptionalMatchedType == WebSocketEngineDelegate {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainNodeModel, ChainNodeConnectable, WebSocketEngineDelegate?)>] = [wrap(matchable: node) { $0.0 }, wrap(matchable: chain) { $0.1 }, wrap(matchable: delegate) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionFactoryProtocol.self, method: "createConnection(for: ChainNodeModel, chain: ChainNodeConnectable, delegate: WebSocketEngineDelegate?) throws -> ChainConnection", parameterMatchers: matchers))
	    }
	    
	    func updateConnection<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ connection: M1, chain: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainConnection, ChainNodeConnectable)> where M1.MatchedType == ChainConnection, M2.MatchedType == ChainNodeConnectable {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainConnection, ChainNodeConnectable)>] = [wrap(matchable: connection) { $0.0 }, wrap(matchable: chain) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionFactoryProtocol.self, method: "updateConnection(_: ChainConnection, chain: ChainNodeConnectable)", parameterMatchers: matchers))
	    }
	    
	    func updateOneShotConnection<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ connection: M1, chain: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(OneShotConnection, ChainNodeConnectable)> where M1.MatchedType == OneShotConnection, M2.MatchedType == ChainNodeConnectable {
	        let matchers: [Cuckoo.ParameterMatcher<(OneShotConnection, ChainNodeConnectable)>] = [wrap(matchable: connection) { $0.0 }, wrap(matchable: chain) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionFactoryProtocol.self, method: "updateOneShotConnection(_: OneShotConnection, chain: ChainNodeConnectable)", parameterMatchers: matchers))
	    }
	    
	    func createOneShotConnection<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.ProtocolStubThrowingFunction<(ChainNodeConnectable), OneShotConnection> where M1.MatchedType == ChainNodeConnectable {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainNodeConnectable)>] = [wrap(matchable: chain) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionFactoryProtocol.self, method: "createOneShotConnection(for: ChainNodeConnectable) throws -> OneShotConnection", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ConnectionFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func createConnection<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable>(for chain: M1, delegate: M2) -> Cuckoo.__DoNotUse<(ChainNodeConnectable, WebSocketEngineDelegate?), ChainConnection> where M1.MatchedType == ChainNodeConnectable, M2.OptionalMatchedType == WebSocketEngineDelegate {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainNodeConnectable, WebSocketEngineDelegate?)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: delegate) { $0.1 }]
	        return cuckoo_manager.verify("createConnection(for: ChainNodeConnectable, delegate: WebSocketEngineDelegate?) throws -> ChainConnection", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createConnection<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable>(for node: M1, chain: M2, delegate: M3) -> Cuckoo.__DoNotUse<(ChainNodeModel, ChainNodeConnectable, WebSocketEngineDelegate?), ChainConnection> where M1.MatchedType == ChainNodeModel, M2.MatchedType == ChainNodeConnectable, M3.OptionalMatchedType == WebSocketEngineDelegate {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainNodeModel, ChainNodeConnectable, WebSocketEngineDelegate?)>] = [wrap(matchable: node) { $0.0 }, wrap(matchable: chain) { $0.1 }, wrap(matchable: delegate) { $0.2 }]
	        return cuckoo_manager.verify("createConnection(for: ChainNodeModel, chain: ChainNodeConnectable, delegate: WebSocketEngineDelegate?) throws -> ChainConnection", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func updateConnection<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ connection: M1, chain: M2) -> Cuckoo.__DoNotUse<(ChainConnection, ChainNodeConnectable), Void> where M1.MatchedType == ChainConnection, M2.MatchedType == ChainNodeConnectable {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainConnection, ChainNodeConnectable)>] = [wrap(matchable: connection) { $0.0 }, wrap(matchable: chain) { $0.1 }]
	        return cuckoo_manager.verify("updateConnection(_: ChainConnection, chain: ChainNodeConnectable)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func updateOneShotConnection<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ connection: M1, chain: M2) -> Cuckoo.__DoNotUse<(OneShotConnection, ChainNodeConnectable), Void> where M1.MatchedType == OneShotConnection, M2.MatchedType == ChainNodeConnectable {
	        let matchers: [Cuckoo.ParameterMatcher<(OneShotConnection, ChainNodeConnectable)>] = [wrap(matchable: connection) { $0.0 }, wrap(matchable: chain) { $0.1 }]
	        return cuckoo_manager.verify("updateOneShotConnection(_: OneShotConnection, chain: ChainNodeConnectable)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createOneShotConnection<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.__DoNotUse<(ChainNodeConnectable), OneShotConnection> where M1.MatchedType == ChainNodeConnectable {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainNodeConnectable)>] = [wrap(matchable: chain) { $0 }]
	        return cuckoo_manager.verify("createOneShotConnection(for: ChainNodeConnectable) throws -> OneShotConnection", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ConnectionFactoryProtocolStub: ConnectionFactoryProtocol {
    

    

    
    
    
     func createConnection(for chain: ChainNodeConnectable, delegate: WebSocketEngineDelegate?) throws -> ChainConnection  {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection).self)
    }
    
    
    
     func createConnection(for node: ChainNodeModel, chain: ChainNodeConnectable, delegate: WebSocketEngineDelegate?) throws -> ChainConnection  {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection).self)
    }
    
    
    
     func updateConnection(_ connection: ChainConnection, chain: ChainNodeConnectable)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func updateOneShotConnection(_ connection: OneShotConnection, chain: ChainNodeConnectable)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func createOneShotConnection(for chain: ChainNodeConnectable) throws -> OneShotConnection  {
        return DefaultValueRegistry.defaultValue(for: (OneShotConnection).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Foundation_iOS
import SubstrateSdk


 class MockConnectionPoolProtocol: ConnectionPoolProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = ConnectionPoolProtocol
    
     typealias Stubbing = __StubbingProxy_ConnectionPoolProtocol
     typealias Verification = __VerificationProxy_ConnectionPoolProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ConnectionPoolProtocol?

     func enableDefaultImplementation(_ stub: ConnectionPoolProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setupConnection(for chain: ChainModel) throws -> ChainConnection {
        
    return try cuckoo_manager.callThrows("setupConnection(for: ChainModel) throws -> ChainConnection",
            parameters: (chain),
            escapingParameters: (chain),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setupConnection(for: chain))
        
    }
    
    
    
     func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        
    return cuckoo_manager.call("getConnection(for: ChainModel.Id) -> ChainConnection?",
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.getConnection(for: chainId))
        
    }
    
    
    
     func subscribe(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call("subscribe(_: ConnectionStateSubscription, chainId: ChainModel.Id)",
            parameters: (subscriber, chainId),
            escapingParameters: (subscriber, chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.subscribe(subscriber, chainId: chainId))
        
    }
    
    
    
     func unsubscribe(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call("unsubscribe(_: ConnectionStateSubscription, chainId: ChainModel.Id)",
            parameters: (subscriber, chainId),
            escapingParameters: (subscriber, chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.unsubscribe(subscriber, chainId: chainId))
        
    }
    
    
    
     func getOneShotConnection(for chain: ChainModel) -> JSONRPCEngine? {
        
    return cuckoo_manager.call("getOneShotConnection(for: ChainModel) -> JSONRPCEngine?",
            parameters: (chain),
            escapingParameters: (chain),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.getOneShotConnection(for: chain))
        
    }
    
    
    
     func deactivateConnection(for chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call("deactivateConnection(for: ChainModel.Id)",
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.deactivateConnection(for: chainId))
        
    }
    

	 struct __StubbingProxy_ConnectionPoolProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setupConnection<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.ProtocolStubThrowingFunction<(ChainModel), ChainConnection> where M1.MatchedType == ChainModel {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self, method: "setupConnection(for: ChainModel) throws -> ChainConnection", parameterMatchers: matchers))
	    }
	    
	    func getConnection<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), ChainConnection?> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self, method: "getConnection(for: ChainModel.Id) -> ChainConnection?", parameterMatchers: matchers))
	    }
	    
	    func subscribe<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ subscriber: M1, chainId: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionStateSubscription, ChainModel.Id)> where M1.MatchedType == ConnectionStateSubscription, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionStateSubscription, ChainModel.Id)>] = [wrap(matchable: subscriber) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self, method: "subscribe(_: ConnectionStateSubscription, chainId: ChainModel.Id)", parameterMatchers: matchers))
	    }
	    
	    func unsubscribe<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ subscriber: M1, chainId: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ConnectionStateSubscription, ChainModel.Id)> where M1.MatchedType == ConnectionStateSubscription, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionStateSubscription, ChainModel.Id)>] = [wrap(matchable: subscriber) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self, method: "unsubscribe(_: ConnectionStateSubscription, chainId: ChainModel.Id)", parameterMatchers: matchers))
	    }
	    
	    func getOneShotConnection<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel), JSONRPCEngine?> where M1.MatchedType == ChainModel {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self, method: "getOneShotConnection(for: ChainModel) -> JSONRPCEngine?", parameterMatchers: matchers))
	    }
	    
	    func deactivateConnection<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel.Id)> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionPoolProtocol.self, method: "deactivateConnection(for: ChainModel.Id)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ConnectionPoolProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setupConnection<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.__DoNotUse<(ChainModel), ChainConnection> where M1.MatchedType == ChainModel {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
	        return cuckoo_manager.verify("setupConnection(for: ChainModel) throws -> ChainConnection", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func getConnection<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), ChainConnection?> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return cuckoo_manager.verify("getConnection(for: ChainModel.Id) -> ChainConnection?", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func subscribe<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ subscriber: M1, chainId: M2) -> Cuckoo.__DoNotUse<(ConnectionStateSubscription, ChainModel.Id), Void> where M1.MatchedType == ConnectionStateSubscription, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionStateSubscription, ChainModel.Id)>] = [wrap(matchable: subscriber) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return cuckoo_manager.verify("subscribe(_: ConnectionStateSubscription, chainId: ChainModel.Id)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func unsubscribe<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(_ subscriber: M1, chainId: M2) -> Cuckoo.__DoNotUse<(ConnectionStateSubscription, ChainModel.Id), Void> where M1.MatchedType == ConnectionStateSubscription, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ConnectionStateSubscription, ChainModel.Id)>] = [wrap(matchable: subscriber) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return cuckoo_manager.verify("unsubscribe(_: ConnectionStateSubscription, chainId: ChainModel.Id)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func getOneShotConnection<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.__DoNotUse<(ChainModel), JSONRPCEngine?> where M1.MatchedType == ChainModel {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
	        return cuckoo_manager.verify("getOneShotConnection(for: ChainModel) -> JSONRPCEngine?", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func deactivateConnection<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Void> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return cuckoo_manager.verify("deactivateConnection(for: ChainModel.Id)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ConnectionPoolProtocolStub: ConnectionPoolProtocol {
    

    

    
    
    
     func setupConnection(for chain: ChainModel) throws -> ChainConnection  {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection).self)
    }
    
    
    
     func getConnection(for chainId: ChainModel.Id) -> ChainConnection?  {
        return DefaultValueRegistry.defaultValue(for: (ChainConnection?).self)
    }
    
    
    
     func subscribe(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func unsubscribe(_ subscriber: ConnectionStateSubscription, chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func getOneShotConnection(for chain: ChainModel) -> JSONRPCEngine?  {
        return DefaultValueRegistry.defaultValue(for: (JSONRPCEngine?).self)
    }
    
    
    
     func deactivateConnection(for chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockConnectionStateSubscription: ConnectionStateSubscription, Cuckoo.ProtocolMock {
    
     typealias MocksType = ConnectionStateSubscription
    
     typealias Stubbing = __StubbingProxy_ConnectionStateSubscription
     typealias Verification = __VerificationProxy_ConnectionStateSubscription

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: ConnectionStateSubscription?

     func enableDefaultImplementation(_ stub: ConnectionStateSubscription) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call("didReceive(state: WebSocketEngine.State, for: ChainModel.Id)",
            parameters: (state, chainId),
            escapingParameters: (state, chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didReceive(state: state, for: chainId))
        
    }
    
    
    
     func didSwitchURL(_ connection: ChainConnection, newURL: URL, for chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call("didSwitchURL(_: ChainConnection, newURL: URL, for: ChainModel.Id)",
            parameters: (connection, newURL, chainId),
            escapingParameters: (connection, newURL, chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.didSwitchURL(connection, newURL: newURL, for: chainId))
        
    }
    

	 struct __StubbingProxy_ConnectionStateSubscription: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(state: M1, for chainId: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(WebSocketEngine.State, ChainModel.Id)> where M1.MatchedType == WebSocketEngine.State, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(WebSocketEngine.State, ChainModel.Id)>] = [wrap(matchable: state) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionStateSubscription.self, method: "didReceive(state: WebSocketEngine.State, for: ChainModel.Id)", parameterMatchers: matchers))
	    }
	    
	    func didSwitchURL<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(_ connection: M1, newURL: M2, for chainId: M3) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainConnection, URL, ChainModel.Id)> where M1.MatchedType == ChainConnection, M2.MatchedType == URL, M3.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainConnection, URL, ChainModel.Id)>] = [wrap(matchable: connection) { $0.0 }, wrap(matchable: newURL) { $0.1 }, wrap(matchable: chainId) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockConnectionStateSubscription.self, method: "didSwitchURL(_: ChainConnection, newURL: URL, for: ChainModel.Id)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_ConnectionStateSubscription: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func didReceive<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(state: M1, for chainId: M2) -> Cuckoo.__DoNotUse<(WebSocketEngine.State, ChainModel.Id), Void> where M1.MatchedType == WebSocketEngine.State, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(WebSocketEngine.State, ChainModel.Id)>] = [wrap(matchable: state) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return cuckoo_manager.verify("didReceive(state: WebSocketEngine.State, for: ChainModel.Id)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func didSwitchURL<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(_ connection: M1, newURL: M2, for chainId: M3) -> Cuckoo.__DoNotUse<(ChainConnection, URL, ChainModel.Id), Void> where M1.MatchedType == ChainConnection, M2.MatchedType == URL, M3.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainConnection, URL, ChainModel.Id)>] = [wrap(matchable: connection) { $0.0 }, wrap(matchable: newURL) { $0.1 }, wrap(matchable: chainId) { $0.2 }]
	        return cuckoo_manager.verify("didSwitchURL(_: ChainConnection, newURL: URL, for: ChainModel.Id)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class ConnectionStateSubscriptionStub: ConnectionStateSubscription {
    

    

    
    
    
     func didReceive(state: WebSocketEngine.State, for chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func didSwitchURL(_ connection: ChainConnection, newURL: URL, for chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockConnectionPool: ConnectionPool, Cuckoo.ClassMock {
    
     typealias MocksType = ConnectionPool
    
     typealias Stubbing = __StubbingProxy_ConnectionPool
     typealias Verification = __VerificationProxy_ConnectionPool

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    
    private var __defaultImplStub: ConnectionPool?

     func enableDefaultImplementation(_ stub: ConnectionPool) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     override var connections: [ChainModel.Id: WeakWrapper] {
        get {
            return cuckoo_manager.getter("connections",
                superclassCall:
                    
                    super.connections
                    ,
                defaultCall: __defaultImplStub!.connections)
        }
        
    }
    
    
    
     override var oneShotConnections: [ChainModel.Id: OneShotConnection] {
        get {
            return cuckoo_manager.getter("oneShotConnections",
                superclassCall:
                    
                    super.oneShotConnections
                    ,
                defaultCall: __defaultImplStub!.oneShotConnections)
        }
        
    }
    
    
    
     override var stateSubscriptions: [ChainModel.Id: [WeakWrapper]] {
        get {
            return cuckoo_manager.getter("stateSubscriptions",
                superclassCall:
                    
                    super.stateSubscriptions
                    ,
                defaultCall: __defaultImplStub!.stateSubscriptions)
        }
        
    }
    

    

    

	 struct __StubbingProxy_ConnectionPool: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var connections: Cuckoo.ClassToBeStubbedReadOnlyProperty<MockConnectionPool, [ChainModel.Id: WeakWrapper]> {
	        return .init(manager: cuckoo_manager, name: "connections")
	    }
	    
	    
	    var oneShotConnections: Cuckoo.ClassToBeStubbedReadOnlyProperty<MockConnectionPool, [ChainModel.Id: OneShotConnection]> {
	        return .init(manager: cuckoo_manager, name: "oneShotConnections")
	    }
	    
	    
	    var stateSubscriptions: Cuckoo.ClassToBeStubbedReadOnlyProperty<MockConnectionPool, [ChainModel.Id: [WeakWrapper]]> {
	        return .init(manager: cuckoo_manager, name: "stateSubscriptions")
	    }
	    
	    
	}

	 struct __VerificationProxy_ConnectionPool: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var connections: Cuckoo.VerifyReadOnlyProperty<[ChainModel.Id: WeakWrapper]> {
	        return .init(manager: cuckoo_manager, name: "connections", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var oneShotConnections: Cuckoo.VerifyReadOnlyProperty<[ChainModel.Id: OneShotConnection]> {
	        return .init(manager: cuckoo_manager, name: "oneShotConnections", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var stateSubscriptions: Cuckoo.VerifyReadOnlyProperty<[ChainModel.Id: [WeakWrapper]]> {
	        return .init(manager: cuckoo_manager, name: "stateSubscriptions", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

 class ConnectionPoolStub: ConnectionPool {
        
    
    
     override var connections: [ChainModel.Id: WeakWrapper] {
        get {
            return DefaultValueRegistry.defaultValue(for: ([ChainModel.Id: WeakWrapper]).self)
        }
        
    }
        
    
    
     override var oneShotConnections: [ChainModel.Id: OneShotConnection] {
        get {
            return DefaultValueRegistry.defaultValue(for: ([ChainModel.Id: OneShotConnection]).self)
        }
        
    }
        
    
    
     override var stateSubscriptions: [ChainModel.Id: [WeakWrapper]] {
        get {
            return DefaultValueRegistry.defaultValue(for: ([ChainModel.Id: [WeakWrapper]]).self)
        }
        
    }
    

    

    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Operation_iOS


 class MockRuntimeFilesOperationFactoryProtocol: RuntimeFilesOperationFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RuntimeFilesOperationFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_RuntimeFilesOperationFactoryProtocol
     typealias Verification = __VerificationProxy_RuntimeFilesOperationFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RuntimeFilesOperationFactoryProtocol?

     func enableDefaultImplementation(_ stub: RuntimeFilesOperationFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?> {
        
    return cuckoo_manager.call("fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchCommonTypesOperation())
        
    }
    
    
    
     func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?> {
        
    return cuckoo_manager.call("fetchChainTypesOperation(for: ChainModel.Id) -> CompoundOperationWrapper<Data?>",
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchChainTypesOperation(for: chainId))
        
    }
    
    
    
     func saveCommonTypesOperation(data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        
    return cuckoo_manager.call("saveCommonTypesOperation(data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>",
            parameters: (closure),
            escapingParameters: (closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.saveCommonTypesOperation(data: closure))
        
    }
    
    
    
     func saveChainTypesOperation(for chainId: ChainModel.Id, data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void> {
        
    return cuckoo_manager.call("saveChainTypesOperation(for: ChainModel.Id, data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>",
            parameters: (chainId, closure),
            escapingParameters: (chainId, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.saveChainTypesOperation(for: chainId, data: closure))
        
    }
    

	 struct __StubbingProxy_RuntimeFilesOperationFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func fetchCommonTypesOperation() -> Cuckoo.ProtocolStubFunction<(), CompoundOperationWrapper<Data?>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self, method: "fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>", parameterMatchers: matchers))
	    }
	    
	    func fetchChainTypesOperation<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), CompoundOperationWrapper<Data?>> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self, method: "fetchChainTypesOperation(for: ChainModel.Id) -> CompoundOperationWrapper<Data?>", parameterMatchers: matchers))
	    }
	    
	    func saveCommonTypesOperation<M1: Cuckoo.Matchable>(data closure: M1) -> Cuckoo.ProtocolStubFunction<(() throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType == () throws -> Data {
	        let matchers: [Cuckoo.ParameterMatcher<(() throws -> Data)>] = [wrap(matchable: closure) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self, method: "saveCommonTypesOperation(data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>", parameterMatchers: matchers))
	    }
	    
	    func saveChainTypesOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for chainId: M1, data closure: M2) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id, () throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType == ChainModel.Id, M2.MatchedType == () throws -> Data {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, () throws -> Data)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: closure) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeFilesOperationFactoryProtocol.self, method: "saveChainTypesOperation(for: ChainModel.Id, data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RuntimeFilesOperationFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func fetchCommonTypesOperation() -> Cuckoo.__DoNotUse<(), CompoundOperationWrapper<Data?>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchChainTypesOperation<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), CompoundOperationWrapper<Data?>> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return cuckoo_manager.verify("fetchChainTypesOperation(for: ChainModel.Id) -> CompoundOperationWrapper<Data?>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func saveCommonTypesOperation<M1: Cuckoo.Matchable>(data closure: M1) -> Cuckoo.__DoNotUse<(() throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType == () throws -> Data {
	        let matchers: [Cuckoo.ParameterMatcher<(() throws -> Data)>] = [wrap(matchable: closure) { $0 }]
	        return cuckoo_manager.verify("saveCommonTypesOperation(data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func saveChainTypesOperation<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for chainId: M1, data closure: M2) -> Cuckoo.__DoNotUse<(ChainModel.Id, () throws -> Data), CompoundOperationWrapper<Void>> where M1.MatchedType == ChainModel.Id, M2.MatchedType == () throws -> Data {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, () throws -> Data)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: closure) { $0.1 }]
	        return cuckoo_manager.verify("saveChainTypesOperation(for: ChainModel.Id, data: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RuntimeFilesOperationFactoryProtocolStub: RuntimeFilesOperationFactoryProtocol {
    

    

    
    
    
     func fetchCommonTypesOperation() -> CompoundOperationWrapper<Data?>  {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Data?>).self)
    }
    
    
    
     func fetchChainTypesOperation(for chainId: ChainModel.Id) -> CompoundOperationWrapper<Data?>  {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Data?>).self)
    }
    
    
    
     func saveCommonTypesOperation(data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>  {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Void>).self)
    }
    
    
    
     func saveChainTypesOperation(for chainId: ChainModel.Id, data closure: @escaping () throws -> Data) -> CompoundOperationWrapper<Void>  {
        return DefaultValueRegistry.defaultValue(for: (CompoundOperationWrapper<Void>).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Operation_iOS
import SubstrateSdk


 class MockCommonTypesSyncServiceProtocol: CommonTypesSyncServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = CommonTypesSyncServiceProtocol
    
     typealias Stubbing = __StubbingProxy_CommonTypesSyncServiceProtocol
     typealias Verification = __VerificationProxy_CommonTypesSyncServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: CommonTypesSyncServiceProtocol?

     func enableDefaultImplementation(_ stub: CommonTypesSyncServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func syncUp()  {
        
    return cuckoo_manager.call("syncUp()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.syncUp())
        
    }
    

	 struct __StubbingProxy_CommonTypesSyncServiceProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func syncUp() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockCommonTypesSyncServiceProtocol.self, method: "syncUp()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_CommonTypesSyncServiceProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func syncUp() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("syncUp()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class CommonTypesSyncServiceProtocolStub: CommonTypesSyncServiceProtocol {
    

    

    
    
    
     func syncUp()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockCommonTypesSyncService: CommonTypesSyncService, Cuckoo.ClassMock {
    
     typealias MocksType = CommonTypesSyncService
    
     typealias Stubbing = __StubbingProxy_CommonTypesSyncService
     typealias Verification = __VerificationProxy_CommonTypesSyncService

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    
    private var __defaultImplStub: CommonTypesSyncService?

     func enableDefaultImplementation(_ stub: CommonTypesSyncService) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     override var isSyncing: Bool {
        get {
            return cuckoo_manager.getter("isSyncing",
                superclassCall:
                    
                    super.isSyncing
                    ,
                defaultCall: __defaultImplStub!.isSyncing)
        }
        
    }
    
    
    
     override var retryAttempt: Int {
        get {
            return cuckoo_manager.getter("retryAttempt",
                superclassCall:
                    
                    super.retryAttempt
                    ,
                defaultCall: __defaultImplStub!.retryAttempt)
        }
        
    }
    

    

    

	 struct __StubbingProxy_CommonTypesSyncService: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var isSyncing: Cuckoo.ClassToBeStubbedReadOnlyProperty<MockCommonTypesSyncService, Bool> {
	        return .init(manager: cuckoo_manager, name: "isSyncing")
	    }
	    
	    
	    var retryAttempt: Cuckoo.ClassToBeStubbedReadOnlyProperty<MockCommonTypesSyncService, Int> {
	        return .init(manager: cuckoo_manager, name: "retryAttempt")
	    }
	    
	    
	}

	 struct __VerificationProxy_CommonTypesSyncService: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var isSyncing: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "isSyncing", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var retryAttempt: Cuckoo.VerifyReadOnlyProperty<Int> {
	        return .init(manager: cuckoo_manager, name: "retryAttempt", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	}
}

 class CommonTypesSyncServiceStub: CommonTypesSyncService {
        
    
    
     override var isSyncing: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
        
    
    
     override var retryAttempt: Int {
        get {
            return DefaultValueRegistry.defaultValue(for: (Int).self)
        }
        
    }
    

    

    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Operation_iOS


 class MockRuntimeCodingServiceProtocol: RuntimeCodingServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RuntimeCodingServiceProtocol
    
     typealias Stubbing = __StubbingProxy_RuntimeCodingServiceProtocol
     typealias Verification = __VerificationProxy_RuntimeCodingServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RuntimeCodingServiceProtocol?

     func enableDefaultImplementation(_ stub: RuntimeCodingServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        
    return cuckoo_manager.call("fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchCoderFactoryOperation())
        
    }
    

	 struct __StubbingProxy_RuntimeCodingServiceProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func fetchCoderFactoryOperation() -> Cuckoo.ProtocolStubFunction<(), BaseOperation<RuntimeCoderFactoryProtocol>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeCodingServiceProtocol.self, method: "fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RuntimeCodingServiceProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func fetchCoderFactoryOperation() -> Cuckoo.__DoNotUse<(), BaseOperation<RuntimeCoderFactoryProtocol>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RuntimeCodingServiceProtocolStub: RuntimeCodingServiceProtocol {
    

    

    
    
    
     func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<RuntimeCoderFactoryProtocol>).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Operation_iOS
import SubstrateSdk


 class MockRuntimeProviderProtocol: RuntimeProviderProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RuntimeProviderProtocol
    
     typealias Stubbing = __StubbingProxy_RuntimeProviderProtocol
     typealias Verification = __VerificationProxy_RuntimeProviderProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RuntimeProviderProtocol?

     func enableDefaultImplementation(_ stub: RuntimeProviderProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    
    
    
     var chainId: ChainModel.Id {
        get {
            return cuckoo_manager.getter("chainId",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.chainId)
        }
        
    }
    
    
    
     var hasSnapshot: Bool {
        get {
            return cuckoo_manager.getter("hasSnapshot",
                superclassCall:
                    
                    Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                    ,
                defaultCall: __defaultImplStub!.hasSnapshot)
        }
        
    }
    

    

    
    
    
     func setup()  {
        
    return cuckoo_manager.call("setup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setup())
        
    }
    
    
    
     func replaceChainData(_ chain: ChainModel)  {
        
    return cuckoo_manager.call("replaceChainData(_: ChainModel)",
            parameters: (chain),
            escapingParameters: (chain),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.replaceChainData(chain))
        
    }
    
    
    
     func cleanup()  {
        
    return cuckoo_manager.call("cleanup()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.cleanup())
        
    }
    
    
    
     func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        
    return cuckoo_manager.call("fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.fetchCoderFactoryOperation())
        
    }
    

	 struct __StubbingProxy_RuntimeProviderProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    var chainId: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockRuntimeProviderProtocol, ChainModel.Id> {
	        return .init(manager: cuckoo_manager, name: "chainId")
	    }
	    
	    
	    var hasSnapshot: Cuckoo.ProtocolToBeStubbedReadOnlyProperty<MockRuntimeProviderProtocol, Bool> {
	        return .init(manager: cuckoo_manager, name: "hasSnapshot")
	    }
	    
	    
	    func setup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderProtocol.self, method: "setup()", parameterMatchers: matchers))
	    }
	    
	    func replaceChainData<M1: Cuckoo.Matchable>(_ chain: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel)> where M1.MatchedType == ChainModel {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderProtocol.self, method: "replaceChainData(_: ChainModel)", parameterMatchers: matchers))
	    }
	    
	    func cleanup() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderProtocol.self, method: "cleanup()", parameterMatchers: matchers))
	    }
	    
	    func fetchCoderFactoryOperation() -> Cuckoo.ProtocolStubFunction<(), BaseOperation<RuntimeCoderFactoryProtocol>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderProtocol.self, method: "fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RuntimeProviderProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	    
	    var chainId: Cuckoo.VerifyReadOnlyProperty<ChainModel.Id> {
	        return .init(manager: cuckoo_manager, name: "chainId", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	    
	    var hasSnapshot: Cuckoo.VerifyReadOnlyProperty<Bool> {
	        return .init(manager: cuckoo_manager, name: "hasSnapshot", callMatcher: callMatcher, sourceLocation: sourceLocation)
	    }
	    
	
	    
	    @discardableResult
	    func setup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("setup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func replaceChainData<M1: Cuckoo.Matchable>(_ chain: M1) -> Cuckoo.__DoNotUse<(ChainModel), Void> where M1.MatchedType == ChainModel {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
	        return cuckoo_manager.verify("replaceChainData(_: ChainModel)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func cleanup() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("cleanup()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func fetchCoderFactoryOperation() -> Cuckoo.__DoNotUse<(), BaseOperation<RuntimeCoderFactoryProtocol>> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RuntimeProviderProtocolStub: RuntimeProviderProtocol {
        
    
    
     var chainId: ChainModel.Id {
        get {
            return DefaultValueRegistry.defaultValue(for: (ChainModel.Id).self)
        }
        
    }
        
    
    
     var hasSnapshot: Bool {
        get {
            return DefaultValueRegistry.defaultValue(for: (Bool).self)
        }
        
    }
    

    

    
    
    
     func setup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func replaceChainData(_ chain: ChainModel)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func cleanup()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>  {
        return DefaultValueRegistry.defaultValue(for: (BaseOperation<RuntimeCoderFactoryProtocol>).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Operation_iOS


 class MockRuntimeProviderFactoryProtocol: RuntimeProviderFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RuntimeProviderFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_RuntimeProviderFactoryProtocol
     typealias Verification = __VerificationProxy_RuntimeProviderFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RuntimeProviderFactoryProtocol?

     func enableDefaultImplementation(_ stub: RuntimeProviderFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func createRuntimeProvider(for chain: ChainModel) -> RuntimeProviderProtocol {
        
    return cuckoo_manager.call("createRuntimeProvider(for: ChainModel) -> RuntimeProviderProtocol",
            parameters: (chain),
            escapingParameters: (chain),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createRuntimeProvider(for: chain))
        
    }
    

	 struct __StubbingProxy_RuntimeProviderFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func createRuntimeProvider<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel), RuntimeProviderProtocol> where M1.MatchedType == ChainModel {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderFactoryProtocol.self, method: "createRuntimeProvider(for: ChainModel) -> RuntimeProviderProtocol", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RuntimeProviderFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func createRuntimeProvider<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.__DoNotUse<(ChainModel), RuntimeProviderProtocol> where M1.MatchedType == ChainModel {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
	        return cuckoo_manager.verify("createRuntimeProvider(for: ChainModel) -> RuntimeProviderProtocol", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RuntimeProviderFactoryProtocolStub: RuntimeProviderFactoryProtocol {
    

    

    
    
    
     func createRuntimeProvider(for chain: ChainModel) -> RuntimeProviderProtocol  {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation


 class MockRuntimeProviderPoolProtocol: RuntimeProviderPoolProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RuntimeProviderPoolProtocol
    
     typealias Stubbing = __StubbingProxy_RuntimeProviderPoolProtocol
     typealias Verification = __VerificationProxy_RuntimeProviderPoolProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RuntimeProviderPoolProtocol?

     func enableDefaultImplementation(_ stub: RuntimeProviderPoolProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setupRuntimeProviderIfNeeded(for chain: ChainModel) -> RuntimeProviderProtocol {
        
    return cuckoo_manager.call("setupRuntimeProviderIfNeeded(for: ChainModel) -> RuntimeProviderProtocol",
            parameters: (chain),
            escapingParameters: (chain),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setupRuntimeProviderIfNeeded(for: chain))
        
    }
    
    
    
     func destroyRuntimeProviderIfExists(for chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call("destroyRuntimeProviderIfExists(for: ChainModel.Id)",
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.destroyRuntimeProviderIfExists(for: chainId))
        
    }
    
    
    
     func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        
    return cuckoo_manager.call("getRuntimeProvider(for: ChainModel.Id) -> RuntimeProviderProtocol?",
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.getRuntimeProvider(for: chainId))
        
    }
    

	 struct __StubbingProxy_RuntimeProviderPoolProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setupRuntimeProviderIfNeeded<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel), RuntimeProviderProtocol> where M1.MatchedType == ChainModel {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderPoolProtocol.self, method: "setupRuntimeProviderIfNeeded(for: ChainModel) -> RuntimeProviderProtocol", parameterMatchers: matchers))
	    }
	    
	    func destroyRuntimeProviderIfExists<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel.Id)> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderPoolProtocol.self, method: "destroyRuntimeProviderIfExists(for: ChainModel.Id)", parameterMatchers: matchers))
	    }
	    
	    func getRuntimeProvider<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), RuntimeProviderProtocol?> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeProviderPoolProtocol.self, method: "getRuntimeProvider(for: ChainModel.Id) -> RuntimeProviderProtocol?", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RuntimeProviderPoolProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setupRuntimeProviderIfNeeded<M1: Cuckoo.Matchable>(for chain: M1) -> Cuckoo.__DoNotUse<(ChainModel), RuntimeProviderProtocol> where M1.MatchedType == ChainModel {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel)>] = [wrap(matchable: chain) { $0 }]
	        return cuckoo_manager.verify("setupRuntimeProviderIfNeeded(for: ChainModel) -> RuntimeProviderProtocol", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func destroyRuntimeProviderIfExists<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Void> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return cuckoo_manager.verify("destroyRuntimeProviderIfExists(for: ChainModel.Id)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func getRuntimeProvider<M1: Cuckoo.Matchable>(for chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), RuntimeProviderProtocol?> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return cuckoo_manager.verify("getRuntimeProvider(for: ChainModel.Id) -> RuntimeProviderProtocol?", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RuntimeProviderPoolProtocolStub: RuntimeProviderPoolProtocol {
    

    

    
    
    
     func setupRuntimeProviderIfNeeded(for chain: ChainModel) -> RuntimeProviderProtocol  {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol).self)
    }
    
    
    
     func destroyRuntimeProviderIfExists(for chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?  {
        return DefaultValueRegistry.defaultValue(for: (RuntimeProviderProtocol?).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Operation_iOS
import SubstrateSdk


 class MockRuntimeSyncServiceProtocol: RuntimeSyncServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = RuntimeSyncServiceProtocol
    
     typealias Stubbing = __StubbingProxy_RuntimeSyncServiceProtocol
     typealias Verification = __VerificationProxy_RuntimeSyncServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: RuntimeSyncServiceProtocol?

     func enableDefaultImplementation(_ stub: RuntimeSyncServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func register(chain: ChainModel, with connection: ChainConnection)  {
        
    return cuckoo_manager.call("register(chain: ChainModel, with: ChainConnection)",
            parameters: (chain, connection),
            escapingParameters: (chain, connection),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.register(chain: chain, with: connection))
        
    }
    
    
    
     func unregisterIfExists(chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call("unregisterIfExists(chainId: ChainModel.Id)",
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.unregisterIfExists(chainId: chainId))
        
    }
    
    
    
     func apply(version: RuntimeVersion, for chainId: ChainModel.Id)  {
        
    return cuckoo_manager.call("apply(version: RuntimeVersion, for: ChainModel.Id)",
            parameters: (version, chainId),
            escapingParameters: (version, chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.apply(version: version, for: chainId))
        
    }
    
    
    
     func hasChain(with chainId: ChainModel.Id) -> Bool {
        
    return cuckoo_manager.call("hasChain(with: ChainModel.Id) -> Bool",
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.hasChain(with: chainId))
        
    }
    
    
    
     func isChainSyncing(_ chainId: ChainModel.Id) -> Bool {
        
    return cuckoo_manager.call("isChainSyncing(_: ChainModel.Id) -> Bool",
            parameters: (chainId),
            escapingParameters: (chainId),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.isChainSyncing(chainId))
        
    }
    

	 struct __StubbingProxy_RuntimeSyncServiceProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func register<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(chain: M1, with connection: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel, ChainConnection)> where M1.MatchedType == ChainModel, M2.MatchedType == ChainConnection {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel, ChainConnection)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: connection) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self, method: "register(chain: ChainModel, with: ChainConnection)", parameterMatchers: matchers))
	    }
	    
	    func unregisterIfExists<M1: Cuckoo.Matchable>(chainId: M1) -> Cuckoo.ProtocolStubNoReturnFunction<(ChainModel.Id)> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self, method: "unregisterIfExists(chainId: ChainModel.Id)", parameterMatchers: matchers))
	    }
	    
	    func apply<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(version: M1, for chainId: M2) -> Cuckoo.ProtocolStubNoReturnFunction<(RuntimeVersion, ChainModel.Id)> where M1.MatchedType == RuntimeVersion, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(RuntimeVersion, ChainModel.Id)>] = [wrap(matchable: version) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self, method: "apply(version: RuntimeVersion, for: ChainModel.Id)", parameterMatchers: matchers))
	    }
	    
	    func hasChain<M1: Cuckoo.Matchable>(with chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), Bool> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self, method: "hasChain(with: ChainModel.Id) -> Bool", parameterMatchers: matchers))
	    }
	    
	    func isChainSyncing<M1: Cuckoo.Matchable>(_ chainId: M1) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id), Bool> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockRuntimeSyncServiceProtocol.self, method: "isChainSyncing(_: ChainModel.Id) -> Bool", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_RuntimeSyncServiceProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func register<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(chain: M1, with connection: M2) -> Cuckoo.__DoNotUse<(ChainModel, ChainConnection), Void> where M1.MatchedType == ChainModel, M2.MatchedType == ChainConnection {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel, ChainConnection)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: connection) { $0.1 }]
	        return cuckoo_manager.verify("register(chain: ChainModel, with: ChainConnection)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func unregisterIfExists<M1: Cuckoo.Matchable>(chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Void> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return cuckoo_manager.verify("unregisterIfExists(chainId: ChainModel.Id)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func apply<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(version: M1, for chainId: M2) -> Cuckoo.__DoNotUse<(RuntimeVersion, ChainModel.Id), Void> where M1.MatchedType == RuntimeVersion, M2.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(RuntimeVersion, ChainModel.Id)>] = [wrap(matchable: version) { $0.0 }, wrap(matchable: chainId) { $0.1 }]
	        return cuckoo_manager.verify("apply(version: RuntimeVersion, for: ChainModel.Id)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func hasChain<M1: Cuckoo.Matchable>(with chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Bool> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return cuckoo_manager.verify("hasChain(with: ChainModel.Id) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func isChainSyncing<M1: Cuckoo.Matchable>(_ chainId: M1) -> Cuckoo.__DoNotUse<(ChainModel.Id), Bool> where M1.MatchedType == ChainModel.Id {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id)>] = [wrap(matchable: chainId) { $0 }]
	        return cuckoo_manager.verify("isChainSyncing(_: ChainModel.Id) -> Bool", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class RuntimeSyncServiceProtocolStub: RuntimeSyncServiceProtocol {
    

    

    
    
    
     func register(chain: ChainModel, with connection: ChainConnection)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func unregisterIfExists(chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func apply(version: RuntimeVersion, for chainId: ChainModel.Id)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func hasChain(with chainId: ChainModel.Id) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
    
    
     func isChainSyncing(_ chainId: ChainModel.Id) -> Bool  {
        return DefaultValueRegistry.defaultValue(for: (Bool).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import SubstrateSdk


 class MockSpecVersionSubscriptionProtocol: SpecVersionSubscriptionProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SpecVersionSubscriptionProtocol
    
     typealias Stubbing = __StubbingProxy_SpecVersionSubscriptionProtocol
     typealias Verification = __VerificationProxy_SpecVersionSubscriptionProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SpecVersionSubscriptionProtocol?

     func enableDefaultImplementation(_ stub: SpecVersionSubscriptionProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func subscribe()  {
        
    return cuckoo_manager.call("subscribe()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.subscribe())
        
    }
    
    
    
     func unsubscribe()  {
        
    return cuckoo_manager.call("unsubscribe()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.unsubscribe())
        
    }
    

	 struct __StubbingProxy_SpecVersionSubscriptionProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func subscribe() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSpecVersionSubscriptionProtocol.self, method: "subscribe()", parameterMatchers: matchers))
	    }
	    
	    func unsubscribe() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockSpecVersionSubscriptionProtocol.self, method: "unsubscribe()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SpecVersionSubscriptionProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func subscribe() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("subscribe()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func unsubscribe() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("unsubscribe()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SpecVersionSubscriptionProtocolStub: SpecVersionSubscriptionProtocol {
    

    

    
    
    
     func subscribe()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func unsubscribe()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import SubstrateSdk


 class MockSpecVersionSubscriptionFactoryProtocol: SpecVersionSubscriptionFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = SpecVersionSubscriptionFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_SpecVersionSubscriptionFactoryProtocol
     typealias Verification = __VerificationProxy_SpecVersionSubscriptionFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: SpecVersionSubscriptionFactoryProtocol?

     func enableDefaultImplementation(_ stub: SpecVersionSubscriptionFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func createSubscription(for chain: ChainModel, connection: JSONRPCEngine) -> SpecVersionSubscriptionProtocol {
        
    return cuckoo_manager.call("createSubscription(for: ChainModel, connection: JSONRPCEngine) -> SpecVersionSubscriptionProtocol",
            parameters: (chain, connection),
            escapingParameters: (chain, connection),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createSubscription(for: chain, connection: connection))
        
    }
    

	 struct __StubbingProxy_SpecVersionSubscriptionFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func createSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for chain: M1, connection: M2) -> Cuckoo.ProtocolStubFunction<(ChainModel, JSONRPCEngine), SpecVersionSubscriptionProtocol> where M1.MatchedType == ChainModel, M2.MatchedType == JSONRPCEngine {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel, JSONRPCEngine)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: connection) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockSpecVersionSubscriptionFactoryProtocol.self, method: "createSubscription(for: ChainModel, connection: JSONRPCEngine) -> SpecVersionSubscriptionProtocol", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_SpecVersionSubscriptionFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func createSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for chain: M1, connection: M2) -> Cuckoo.__DoNotUse<(ChainModel, JSONRPCEngine), SpecVersionSubscriptionProtocol> where M1.MatchedType == ChainModel, M2.MatchedType == JSONRPCEngine {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel, JSONRPCEngine)>] = [wrap(matchable: chain) { $0.0 }, wrap(matchable: connection) { $0.1 }]
	        return cuckoo_manager.verify("createSubscription(for: ChainModel, connection: JSONRPCEngine) -> SpecVersionSubscriptionProtocol", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class SpecVersionSubscriptionFactoryProtocolStub: SpecVersionSubscriptionFactoryProtocol {
    

    

    
    
    
     func createSubscription(for chain: ChainModel, connection: JSONRPCEngine) -> SpecVersionSubscriptionProtocol  {
        return DefaultValueRegistry.defaultValue(for: (SpecVersionSubscriptionProtocol).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation


 class MockCrowdloanRemoteSubscriptionServiceProtocol: CrowdloanRemoteSubscriptionServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = CrowdloanRemoteSubscriptionServiceProtocol
    
     typealias Stubbing = __StubbingProxy_CrowdloanRemoteSubscriptionServiceProtocol
     typealias Verification = __VerificationProxy_CrowdloanRemoteSubscriptionServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: CrowdloanRemoteSubscriptionServiceProtocol?

     func enableDefaultImplementation(_ stub: CrowdloanRemoteSubscriptionServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func attach(for chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?) -> UUID? {
        
    return cuckoo_manager.call("attach(for: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?) -> UUID?",
            parameters: (chainId, queue, closure),
            escapingParameters: (chainId, queue, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.attach(for: chainId, runningCompletionIn: queue, completion: closure))
        
    }
    
    
    
     func detach(for subscriptionId: UUID, chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?)  {
        
    return cuckoo_manager.call("detach(for: UUID, chainId: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?)",
            parameters: (subscriptionId, chainId, queue, closure),
            escapingParameters: (subscriptionId, chainId, queue, closure),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.detach(for: subscriptionId, chainId: chainId, runningCompletionIn: queue, completion: closure))
        
    }
    

	 struct __StubbingProxy_CrowdloanRemoteSubscriptionServiceProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func attach<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(for chainId: M1, runningCompletionIn queue: M2, completion closure: M3) -> Cuckoo.ProtocolStubFunction<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: queue) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockCrowdloanRemoteSubscriptionServiceProtocol.self, method: "attach(for: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?) -> UUID?", parameterMatchers: matchers))
	    }
	    
	    func detach<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainId: M2, runningCompletionIn queue: M3, completion closure: M4) -> Cuckoo.ProtocolStubNoReturnFunction<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
	        let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockCrowdloanRemoteSubscriptionServiceProtocol.self, method: "detach(for: UUID, chainId: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_CrowdloanRemoteSubscriptionServiceProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func attach<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(for chainId: M1, runningCompletionIn queue: M2, completion closure: M3) -> Cuckoo.__DoNotUse<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: queue) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return cuckoo_manager.verify("attach(for: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?) -> UUID?", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func detach<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainId: M2, runningCompletionIn queue: M3, completion closure: M4) -> Cuckoo.__DoNotUse<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), Void> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
	        let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
	        return cuckoo_manager.verify("detach(for: UUID, chainId: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class CrowdloanRemoteSubscriptionServiceProtocolStub: CrowdloanRemoteSubscriptionServiceProtocol {
    

    

    
    
    
     func attach(for chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?) -> UUID?  {
        return DefaultValueRegistry.defaultValue(for: (UUID?).self)
    }
    
    
    
     func detach(for subscriptionId: UUID, chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockCrowdloanRemoteSubscriptionService: CrowdloanRemoteSubscriptionService, Cuckoo.ClassMock {
    
     typealias MocksType = CrowdloanRemoteSubscriptionService
    
     typealias Stubbing = __StubbingProxy_CrowdloanRemoteSubscriptionService
     typealias Verification = __VerificationProxy_CrowdloanRemoteSubscriptionService

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    
    private var __defaultImplStub: CrowdloanRemoteSubscriptionService?

     func enableDefaultImplementation(_ stub: CrowdloanRemoteSubscriptionService) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     override func attach(for chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?) -> UUID? {
        
    return cuckoo_manager.call("attach(for: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?) -> UUID?",
            parameters: (chainId, queue, closure),
            escapingParameters: (chainId, queue, closure),
            superclassCall:
                
                super.attach(for: chainId, runningCompletionIn: queue, completion: closure)
                ,
            defaultCall: __defaultImplStub!.attach(for: chainId, runningCompletionIn: queue, completion: closure))
        
    }
    
    
    
     override func detach(for subscriptionId: UUID, chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?)  {
        
    return cuckoo_manager.call("detach(for: UUID, chainId: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?)",
            parameters: (subscriptionId, chainId, queue, closure),
            escapingParameters: (subscriptionId, chainId, queue, closure),
            superclassCall:
                
                super.detach(for: subscriptionId, chainId: chainId, runningCompletionIn: queue, completion: closure)
                ,
            defaultCall: __defaultImplStub!.detach(for: subscriptionId, chainId: chainId, runningCompletionIn: queue, completion: closure))
        
    }
    

	 struct __StubbingProxy_CrowdloanRemoteSubscriptionService: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func attach<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(for chainId: M1, runningCompletionIn queue: M2, completion closure: M3) -> Cuckoo.ClassStubFunction<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: queue) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockCrowdloanRemoteSubscriptionService.self, method: "attach(for: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?) -> UUID?", parameterMatchers: matchers))
	    }
	    
	    func detach<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainId: M2, runningCompletionIn queue: M3, completion closure: M4) -> Cuckoo.ClassStubNoReturnFunction<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
	        let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockCrowdloanRemoteSubscriptionService.self, method: "detach(for: UUID, chainId: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?)", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_CrowdloanRemoteSubscriptionService: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func attach<M1: Cuckoo.Matchable, M2: Cuckoo.OptionalMatchable, M3: Cuckoo.OptionalMatchable>(for chainId: M1, runningCompletionIn queue: M2, completion closure: M3) -> Cuckoo.__DoNotUse<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), UUID?> where M1.MatchedType == ChainModel.Id, M2.OptionalMatchedType == DispatchQueue, M3.OptionalMatchedType == RemoteSubscriptionClosure {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: queue) { $0.1 }, wrap(matchable: closure) { $0.2 }]
	        return cuckoo_manager.verify("attach(for: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?) -> UUID?", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func detach<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.OptionalMatchable, M4: Cuckoo.OptionalMatchable>(for subscriptionId: M1, chainId: M2, runningCompletionIn queue: M3, completion closure: M4) -> Cuckoo.__DoNotUse<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?), Void> where M1.MatchedType == UUID, M2.MatchedType == ChainModel.Id, M3.OptionalMatchedType == DispatchQueue, M4.OptionalMatchedType == RemoteSubscriptionClosure {
	        let matchers: [Cuckoo.ParameterMatcher<(UUID, ChainModel.Id, DispatchQueue?, RemoteSubscriptionClosure?)>] = [wrap(matchable: subscriptionId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: queue) { $0.2 }, wrap(matchable: closure) { $0.3 }]
	        return cuckoo_manager.verify("detach(for: UUID, chainId: ChainModel.Id, runningCompletionIn: DispatchQueue?, completion: RemoteSubscriptionClosure?)", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class CrowdloanRemoteSubscriptionServiceStub: CrowdloanRemoteSubscriptionService {
    

    

    
    
    
     override func attach(for chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?) -> UUID?  {
        return DefaultValueRegistry.defaultValue(for: (UUID?).self)
    }
    
    
    
     override func detach(for subscriptionId: UUID, chainId: ChainModel.Id, runningCompletionIn queue: DispatchQueue?, completion closure: RemoteSubscriptionClosure?)   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Operation_iOS


 class MockStakingAccountUpdatingServiceProtocol: StakingAccountUpdatingServiceProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingAccountUpdatingServiceProtocol
    
     typealias Stubbing = __StubbingProxy_StakingAccountUpdatingServiceProtocol
     typealias Verification = __VerificationProxy_StakingAccountUpdatingServiceProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingAccountUpdatingServiceProtocol?

     func enableDefaultImplementation(_ stub: StakingAccountUpdatingServiceProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func setupSubscription(for accountId: AccountId, chainId: ChainModel.Id, chainFormat: ChainFormat) throws {
        
    return try cuckoo_manager.callThrows("setupSubscription(for: AccountId, chainId: ChainModel.Id, chainFormat: ChainFormat) throws",
            parameters: (accountId, chainId, chainFormat),
            escapingParameters: (accountId, chainId, chainFormat),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.setupSubscription(for: accountId, chainId: chainId, chainFormat: chainFormat))
        
    }
    
    
    
     func clearSubscription()  {
        
    return cuckoo_manager.call("clearSubscription()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.clearSubscription())
        
    }
    

	 struct __StubbingProxy_StakingAccountUpdatingServiceProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setupSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for accountId: M1, chainId: M2, chainFormat: M3) -> Cuckoo.ProtocolStubNoReturnThrowingFunction<(AccountId, ChainModel.Id, ChainFormat)> where M1.MatchedType == AccountId, M2.MatchedType == ChainModel.Id, M3.MatchedType == ChainFormat {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainModel.Id, ChainFormat)>] = [wrap(matchable: accountId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: chainFormat) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingAccountUpdatingServiceProtocol.self, method: "setupSubscription(for: AccountId, chainId: ChainModel.Id, chainFormat: ChainFormat) throws", parameterMatchers: matchers))
	    }
	    
	    func clearSubscription() -> Cuckoo.ProtocolStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingAccountUpdatingServiceProtocol.self, method: "clearSubscription()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingAccountUpdatingServiceProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setupSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for accountId: M1, chainId: M2, chainFormat: M3) -> Cuckoo.__DoNotUse<(AccountId, ChainModel.Id, ChainFormat), Void> where M1.MatchedType == AccountId, M2.MatchedType == ChainModel.Id, M3.MatchedType == ChainFormat {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainModel.Id, ChainFormat)>] = [wrap(matchable: accountId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: chainFormat) { $0.2 }]
	        return cuckoo_manager.verify("setupSubscription(for: AccountId, chainId: ChainModel.Id, chainFormat: ChainFormat) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func clearSubscription() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("clearSubscription()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingAccountUpdatingServiceProtocolStub: StakingAccountUpdatingServiceProtocol {
    

    

    
    
    
     func setupSubscription(for accountId: AccountId, chainId: ChainModel.Id, chainFormat: ChainFormat) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     func clearSubscription()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}



 class MockStakingAccountUpdatingService: StakingAccountUpdatingService, Cuckoo.ClassMock {
    
     typealias MocksType = StakingAccountUpdatingService
    
     typealias Stubbing = __StubbingProxy_StakingAccountUpdatingService
     typealias Verification = __VerificationProxy_StakingAccountUpdatingService

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: true)

    
    private var __defaultImplStub: StakingAccountUpdatingService?

     func enableDefaultImplementation(_ stub: StakingAccountUpdatingService) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     override func setupSubscription(for accountId: AccountId, chainId: ChainModel.Id, chainFormat: ChainFormat) throws {
        
    return try cuckoo_manager.callThrows("setupSubscription(for: AccountId, chainId: ChainModel.Id, chainFormat: ChainFormat) throws",
            parameters: (accountId, chainId, chainFormat),
            escapingParameters: (accountId, chainId, chainFormat),
            superclassCall:
                
                super.setupSubscription(for: accountId, chainId: chainId, chainFormat: chainFormat)
                ,
            defaultCall: __defaultImplStub!.setupSubscription(for: accountId, chainId: chainId, chainFormat: chainFormat))
        
    }
    
    
    
     override func clearSubscription()  {
        
    return cuckoo_manager.call("clearSubscription()",
            parameters: (),
            escapingParameters: (),
            superclassCall:
                
                super.clearSubscription()
                ,
            defaultCall: __defaultImplStub!.clearSubscription())
        
    }
    

	 struct __StubbingProxy_StakingAccountUpdatingService: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func setupSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for accountId: M1, chainId: M2, chainFormat: M3) -> Cuckoo.ClassStubNoReturnThrowingFunction<(AccountId, ChainModel.Id, ChainFormat)> where M1.MatchedType == AccountId, M2.MatchedType == ChainModel.Id, M3.MatchedType == ChainFormat {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainModel.Id, ChainFormat)>] = [wrap(matchable: accountId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: chainFormat) { $0.2 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingAccountUpdatingService.self, method: "setupSubscription(for: AccountId, chainId: ChainModel.Id, chainFormat: ChainFormat) throws", parameterMatchers: matchers))
	    }
	    
	    func clearSubscription() -> Cuckoo.ClassStubNoReturnFunction<()> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingAccountUpdatingService.self, method: "clearSubscription()", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingAccountUpdatingService: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func setupSubscription<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable>(for accountId: M1, chainId: M2, chainFormat: M3) -> Cuckoo.__DoNotUse<(AccountId, ChainModel.Id, ChainFormat), Void> where M1.MatchedType == AccountId, M2.MatchedType == ChainModel.Id, M3.MatchedType == ChainFormat {
	        let matchers: [Cuckoo.ParameterMatcher<(AccountId, ChainModel.Id, ChainFormat)>] = [wrap(matchable: accountId) { $0.0 }, wrap(matchable: chainId) { $0.1 }, wrap(matchable: chainFormat) { $0.2 }]
	        return cuckoo_manager.verify("setupSubscription(for: AccountId, chainId: ChainModel.Id, chainFormat: ChainFormat) throws", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func clearSubscription() -> Cuckoo.__DoNotUse<(), Void> {
	        let matchers: [Cuckoo.ParameterMatcher<Void>] = []
	        return cuckoo_manager.verify("clearSubscription()", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingAccountUpdatingServiceStub: StakingAccountUpdatingService {
    

    

    
    
    
     override func setupSubscription(for accountId: AccountId, chainId: ChainModel.Id, chainFormat: ChainFormat) throws  {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
    
    
     override func clearSubscription()   {
        return DefaultValueRegistry.defaultValue(for: (Void).self)
    }
    
}


import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import SubstrateSdk

import Cuckoo
@testable import novawallet
@testable import Keystore_iOS

import Foundation
import Operation_iOS


 class MockStakingServiceFactoryProtocol: StakingServiceFactoryProtocol, Cuckoo.ProtocolMock {
    
     typealias MocksType = StakingServiceFactoryProtocol
    
     typealias Stubbing = __StubbingProxy_StakingServiceFactoryProtocol
     typealias Verification = __VerificationProxy_StakingServiceFactoryProtocol

     let cuckoo_manager = Cuckoo.MockManager.preconfiguredManager ?? Cuckoo.MockManager(hasParent: false)

    
    private var __defaultImplStub: StakingServiceFactoryProtocol?

     func enableDefaultImplementation(_ stub: StakingServiceFactoryProtocol) {
        __defaultImplStub = stub
        cuckoo_manager.enableDefaultStubImplementation()
    }
    

    

    

    
    
    
     func createEraValidatorService(for chainId: ChainModel.Id, localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol) throws -> EraValidatorServiceProtocol {
        
    return try cuckoo_manager.callThrows("createEraValidatorService(for: ChainModel.Id, localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol) throws -> EraValidatorServiceProtocol",
            parameters: (chainId, localSubscriptionFactory),
            escapingParameters: (chainId, localSubscriptionFactory),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createEraValidatorService(for: chainId, localSubscriptionFactory: localSubscriptionFactory))
        
    }
    
    
    
     func createRewardCalculatorService(for chainAsset: ChainAsset, stakingType: StakingType, stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol, stakingDurationFactory: StakingDurationOperationFactoryProtocol, validatorService: EraValidatorServiceProtocol) throws -> RewardCalculatorServiceProtocol {
        
    return try cuckoo_manager.callThrows("createRewardCalculatorService(for: ChainAsset, stakingType: StakingType, stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol, stakingDurationFactory: StakingDurationOperationFactoryProtocol, validatorService: EraValidatorServiceProtocol) throws -> RewardCalculatorServiceProtocol",
            parameters: (chainAsset, stakingType, stakingLocalSubscriptionFactory, stakingDurationFactory, validatorService),
            escapingParameters: (chainAsset, stakingType, stakingLocalSubscriptionFactory, stakingDurationFactory, validatorService),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createRewardCalculatorService(for: chainAsset, stakingType: stakingType, stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory, stakingDurationFactory: stakingDurationFactory, validatorService: validatorService))
        
    }
    
    
    
     func createTimeModel(for chainId: ChainModel.Id, consensus: ConsensusType) throws -> StakingTimeModel {
        
    return try cuckoo_manager.callThrows("createTimeModel(for: ChainModel.Id, consensus: ConsensusType) throws -> StakingTimeModel",
            parameters: (chainId, consensus),
            escapingParameters: (chainId, consensus),
            superclassCall:
                
                Cuckoo.MockManager.crashOnProtocolSuperclassCall()
                ,
            defaultCall: __defaultImplStub!.createTimeModel(for: chainId, consensus: consensus))
        
    }
    

	 struct __StubbingProxy_StakingServiceFactoryProtocol: Cuckoo.StubbingProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	
	     init(manager: Cuckoo.MockManager) {
	        self.cuckoo_manager = manager
	    }
	    
	    
	    func createEraValidatorService<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for chainId: M1, localSubscriptionFactory: M2) -> Cuckoo.ProtocolStubThrowingFunction<(ChainModel.Id, StakingLocalSubscriptionFactoryProtocol), EraValidatorServiceProtocol> where M1.MatchedType == ChainModel.Id, M2.MatchedType == StakingLocalSubscriptionFactoryProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, StakingLocalSubscriptionFactoryProtocol)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: localSubscriptionFactory) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingServiceFactoryProtocol.self, method: "createEraValidatorService(for: ChainModel.Id, localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol) throws -> EraValidatorServiceProtocol", parameterMatchers: matchers))
	    }
	    
	    func createRewardCalculatorService<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, M5: Cuckoo.Matchable>(for chainAsset: M1, stakingType: M2, stakingLocalSubscriptionFactory: M3, stakingDurationFactory: M4, validatorService: M5) -> Cuckoo.ProtocolStubThrowingFunction<(ChainAsset, StakingType, StakingLocalSubscriptionFactoryProtocol, StakingDurationOperationFactoryProtocol, EraValidatorServiceProtocol), RewardCalculatorServiceProtocol> where M1.MatchedType == ChainAsset, M2.MatchedType == StakingType, M3.MatchedType == StakingLocalSubscriptionFactoryProtocol, M4.MatchedType == StakingDurationOperationFactoryProtocol, M5.MatchedType == EraValidatorServiceProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainAsset, StakingType, StakingLocalSubscriptionFactoryProtocol, StakingDurationOperationFactoryProtocol, EraValidatorServiceProtocol)>] = [wrap(matchable: chainAsset) { $0.0 }, wrap(matchable: stakingType) { $0.1 }, wrap(matchable: stakingLocalSubscriptionFactory) { $0.2 }, wrap(matchable: stakingDurationFactory) { $0.3 }, wrap(matchable: validatorService) { $0.4 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingServiceFactoryProtocol.self, method: "createRewardCalculatorService(for: ChainAsset, stakingType: StakingType, stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol, stakingDurationFactory: StakingDurationOperationFactoryProtocol, validatorService: EraValidatorServiceProtocol) throws -> RewardCalculatorServiceProtocol", parameterMatchers: matchers))
	    }
	    
	    func createTimeModel<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for chainId: M1, consensus: M2) -> Cuckoo.ProtocolStubThrowingFunction<(ChainModel.Id, ConsensusType), StakingTimeModel> where M1.MatchedType == ChainModel.Id, M2.MatchedType == ConsensusType {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, ConsensusType)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: consensus) { $0.1 }]
	        return .init(stub: cuckoo_manager.createStub(for: MockStakingServiceFactoryProtocol.self, method: "createTimeModel(for: ChainModel.Id, consensus: ConsensusType) throws -> StakingTimeModel", parameterMatchers: matchers))
	    }
	    
	}

	 struct __VerificationProxy_StakingServiceFactoryProtocol: Cuckoo.VerificationProxy {
	    private let cuckoo_manager: Cuckoo.MockManager
	    private let callMatcher: Cuckoo.CallMatcher
	    private let sourceLocation: Cuckoo.SourceLocation
	
	     init(manager: Cuckoo.MockManager, callMatcher: Cuckoo.CallMatcher, sourceLocation: Cuckoo.SourceLocation) {
	        self.cuckoo_manager = manager
	        self.callMatcher = callMatcher
	        self.sourceLocation = sourceLocation
	    }
	
	    
	
	    
	    @discardableResult
	    func createEraValidatorService<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for chainId: M1, localSubscriptionFactory: M2) -> Cuckoo.__DoNotUse<(ChainModel.Id, StakingLocalSubscriptionFactoryProtocol), EraValidatorServiceProtocol> where M1.MatchedType == ChainModel.Id, M2.MatchedType == StakingLocalSubscriptionFactoryProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, StakingLocalSubscriptionFactoryProtocol)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: localSubscriptionFactory) { $0.1 }]
	        return cuckoo_manager.verify("createEraValidatorService(for: ChainModel.Id, localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol) throws -> EraValidatorServiceProtocol", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createRewardCalculatorService<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable, M3: Cuckoo.Matchable, M4: Cuckoo.Matchable, M5: Cuckoo.Matchable>(for chainAsset: M1, stakingType: M2, stakingLocalSubscriptionFactory: M3, stakingDurationFactory: M4, validatorService: M5) -> Cuckoo.__DoNotUse<(ChainAsset, StakingType, StakingLocalSubscriptionFactoryProtocol, StakingDurationOperationFactoryProtocol, EraValidatorServiceProtocol), RewardCalculatorServiceProtocol> where M1.MatchedType == ChainAsset, M2.MatchedType == StakingType, M3.MatchedType == StakingLocalSubscriptionFactoryProtocol, M4.MatchedType == StakingDurationOperationFactoryProtocol, M5.MatchedType == EraValidatorServiceProtocol {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainAsset, StakingType, StakingLocalSubscriptionFactoryProtocol, StakingDurationOperationFactoryProtocol, EraValidatorServiceProtocol)>] = [wrap(matchable: chainAsset) { $0.0 }, wrap(matchable: stakingType) { $0.1 }, wrap(matchable: stakingLocalSubscriptionFactory) { $0.2 }, wrap(matchable: stakingDurationFactory) { $0.3 }, wrap(matchable: validatorService) { $0.4 }]
	        return cuckoo_manager.verify("createRewardCalculatorService(for: ChainAsset, stakingType: StakingType, stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol, stakingDurationFactory: StakingDurationOperationFactoryProtocol, validatorService: EraValidatorServiceProtocol) throws -> RewardCalculatorServiceProtocol", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	    @discardableResult
	    func createTimeModel<M1: Cuckoo.Matchable, M2: Cuckoo.Matchable>(for chainId: M1, consensus: M2) -> Cuckoo.__DoNotUse<(ChainModel.Id, ConsensusType), StakingTimeModel> where M1.MatchedType == ChainModel.Id, M2.MatchedType == ConsensusType {
	        let matchers: [Cuckoo.ParameterMatcher<(ChainModel.Id, ConsensusType)>] = [wrap(matchable: chainId) { $0.0 }, wrap(matchable: consensus) { $0.1 }]
	        return cuckoo_manager.verify("createTimeModel(for: ChainModel.Id, consensus: ConsensusType) throws -> StakingTimeModel", callMatcher: callMatcher, parameterMatchers: matchers, sourceLocation: sourceLocation)
	    }
	    
	}
}

 class StakingServiceFactoryProtocolStub: StakingServiceFactoryProtocol {
    

    

    
    
    
     func createEraValidatorService(for chainId: ChainModel.Id, localSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol) throws -> EraValidatorServiceProtocol  {
        return DefaultValueRegistry.defaultValue(for: (EraValidatorServiceProtocol).self)
    }
    
    
    
     func createRewardCalculatorService(for chainAsset: ChainAsset, stakingType: StakingType, stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol, stakingDurationFactory: StakingDurationOperationFactoryProtocol, validatorService: EraValidatorServiceProtocol) throws -> RewardCalculatorServiceProtocol  {
        return DefaultValueRegistry.defaultValue(for: (RewardCalculatorServiceProtocol).self)
    }
    
    
    
     func createTimeModel(for chainId: ChainModel.Id, consensus: ConsensusType) throws -> StakingTimeModel  {
        return DefaultValueRegistry.defaultValue(for: (StakingTimeModel).self)
    }
    
}

