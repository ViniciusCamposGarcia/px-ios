//
//  PXBiometricConfig.swift
//  MercadoPagoSDK
//
//  Created by Juan sebastian Sanzone on 8/8/19.
//

import Foundation

/**
 Whe use this object to store properties related to Biometric module.
Check PXBiometricProtocol methods.
 */
@objcMembers
open class PXBiometricConfig: NSObject {
    public let flowIdentifier: String
    public var params: [String: Any] = [:]

    internal enum ParamKey: String {
        case amount
    }

    init(_ flowIdentifier: String) {
        self.flowIdentifier = flowIdentifier
    }
}

// MARK: Internals (Only PX)
internal extension PXBiometricConfig {
    func setAmount(_ amount: NSDecimalNumber) {
        self.params[ParamKey.amount.rawValue] = amount
    }

    func setParam(key: String, value: Any) {
        self.params[key] = value
    }

    static func createConfig(withFlowIdentifier: String? = nil, andAmount: NSDecimalNumber? = nil) -> PXBiometricConfig {
        let pxProductId: String = "BJEO9TFBF6RG01IIIOU0"
        var defaultConfig = PXBiometricConfig(pxProductId)

        if let flowIdentifier = withFlowIdentifier {
            defaultConfig = PXBiometricConfig(flowIdentifier)
        }

        guard let amount = andAmount else { return defaultConfig }
        defaultConfig.setAmount(amount)
        return defaultConfig
    }
}

/**
Use this protocol to implement Biometric validation
*/
@objc public protocol PXBiometricProtocol: NSObjectProtocol {
	func validate(config: PXBiometricConfig, onSuccess: @escaping () -> Void, onError: @escaping (Error) -> Void)
	func isValidationRequired(config: PXBiometricConfig) -> Bool
}

/**
Default PX implementation of Biometric for public distribution. (No-validation)
*/
final class PXBiometricDefault: NSObject, PXBiometricProtocol {
	func validate(config: PXBiometricConfig, onSuccess: @escaping () -> Void, onError: (Error) -> Void) {
		onSuccess()
	}
	
	func isValidationRequired(config: PXBiometricConfig) -> Bool {
		return false
	}
}
