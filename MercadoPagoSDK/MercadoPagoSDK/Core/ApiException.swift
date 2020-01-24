//
//  ApiException.swift
//  MercadoPagoSDK
//
//  Created by Mauro Reverter on 6/30/17.
//  Copyright © 2017 MercadoPago. All rights reserved.
//

import Foundation

internal class ApiException {

    open var cause: [Cause]?
    open var error: String?
    open var message: String?
    open var status: Int = 0
    open class func fromJSON(_ json: NSDictionary) -> ApiException {
        let apiException: ApiException = ApiException()
        if let status = JSONHandler.attemptParseToInt(json["status"]) {
            apiException.status = status
        }
        if let message = JSONHandler.attemptParseToString(json["message"]) {
            apiException.message = message
        }
        if let error = JSONHandler.attemptParseToString(json["error"]) {
            apiException.error = error
        }
        var cause: [Cause] = [Cause]()
        if let causeArray = json["cause"] as? NSArray {
            for index in 0..<causeArray.count {
                if let causeDic = causeArray[index] as? NSDictionary {
                    cause.append(Cause.fromJSON(causeDic))
                }
            }
        }
        apiException.cause = cause

        return apiException
    }
    func containsCause(code: String) -> Bool {
        if self.cause != nil {
            for currentCause in self.cause! where code == currentCause.code {
                return true
            }
        }
        return false
    }
}

struct HtmlStorageObject {
	let id: Int
	let html: String
}

class HtmlStorage {
	private var htmlStorage: [HtmlStorageObject] = [HtmlStorageObject]()
	let baseUrl: String = "pxHtml://"
	static let shared = HtmlStorage()
	
	func set(_ targetHtml: String) -> String {
		let targetId = htmlStorage.count + 1
		let element = HtmlStorageObject(id: targetId, html: targetHtml)
		htmlStorage.append(element)
		return "\(baseUrl)\(targetId)"
	}
	
	func getHtml(_ url: String) -> String? {
		let targetIdStr = url.replacingOccurrences(of: baseUrl, with: "")
		if let targetId = Int(targetIdStr) {
			let htmlFound = htmlStorage.filter { (storage: HtmlStorageObject) -> Bool in
				return storage.id == targetId
			}
			if let founded = htmlFound.first {
				return founded.html
			}
		}
		return nil
	}
	
	func clean() {
		htmlStorage.removeAll()
	}
}

internal class JSONHandler: NSObject {
	
	class func jsonCoding(_ jsonDictionary: [String: Any]) -> String {
		var result: String = ""
		do {
			let dict = NSMutableDictionary()
			for (key, value) in jsonDictionary {
				dict.setValue(value as AnyObject, forKey: key)
			}
			let jsonData = try JSONSerialization.data(withJSONObject: dict)
			if let strResult = NSString(data: jsonData, encoding: String.Encoding.ascii.rawValue) as String? {
				result = strResult
			}
		} catch {
			print("ERROR CONVERTING ARRAY TO JSON, ERROR = \(error)")
		}
		return result
	}
	
	class func parseToJSON(_ data: Data) -> Any {
		var result: Any = []
		do {
			result = try JSONSerialization.jsonObject(with: data, options: [])
		} catch {
			print("ERROR PARSING JSON, ERROR = \(error)")
		}
		return result
	}
	
	class func attemptParseToBool(_ anyobject: Any?) -> Bool? {
		if anyobject is Bool {
			return anyobject as! Bool?
		}
		guard let string = attemptParseToString(anyobject) else {
			return nil
		}
		return string.toBool()
	}
	
	class func attemptParseToDouble(_ anyobject: Any?, defaultReturn: Double? = nil) -> Double? {
		
		guard let string = attemptParseToString(anyobject) else {
			return defaultReturn
		}
		return Double(string) ?? defaultReturn
	}
	
	class func convertToDictionary(text: String) -> [String: Any]? {
		if let data = text.data(using: .utf8) {
			do {
				return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
			} catch {
				print(error.localizedDescription)
			}
		}
		return nil
	}
	
	class func attemptParseToString(_ anyobject: Any?, defaultReturn: String? = nil) -> String? {
		
		guard anyobject != nil, let string = (anyobject! as AnyObject).description else {
			return defaultReturn
		}
		if  string != "<null>" {
			return string
		} else {
			return defaultReturn
		}
	}
	
	class func attemptParseToInt(_ anyobject: Any?, defaultReturn: Int? = nil) -> Int? {
		
		guard let string = attemptParseToString(anyobject) else {
			return defaultReturn
		}
		return Int(string) ?? defaultReturn
	}
	
	class func getValue<T>(of type: T.Type, key: String, from json: NSDictionary) -> T {
		guard let value = json[key] as? T else {
			let errorPlace: String = "Error in class: \(#file) , function:  \(#function), line: \(#line)"
			fatalError("Could not get value for key: \(key). " + errorPlace )
		}
		return value
	}
	
	internal class var null: NSNull { return NSNull() }
}

internal extension String {
	func toBool() -> Bool? {
		switch self {
		case "True", "true", "YES", "yes", "1":
			return true
		case "False", "false", "NO", "no", "0":
			return false
		default:
			return nil
		}
	}
}

internal extension String {
	
	var numberValue: NSNumber? {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		return formatter.number(from: self)
	}
}


//will only execute the print action if running in debug
internal func printDebug(_ items: Any..., separator: String = " ", terminator: String = "\n") {
	#if DEBUG
	let output = items.map { "\($0)" }.joined(separator: separator)
	Swift.print(output, terminator: terminator)
	#endif
}

//this function should be used when the user experience has been broken and this log needs to be reported as a warning in order to be fixed in a further version
internal func printError(_ items: Any..., separator: String = " ", terminator: String = "\n") {
	#if DEBUG
	let output = items.map { "\($0)" }.joined(separator: separator)
	Swift.debugPrint(output, terminator: terminator)
	#endif
}


// MARK: Tracking
extension MercadoPagoCheckout {
	
	internal func startTracking() {
		MPXTracker.sharedInstance.startNewSession()
		
		// Track init event
		var properties: [String: Any] = [:]
		if !String.isNullOrEmpty(viewModel.checkoutPreference.id) {
			properties["checkout_preference_id"] = viewModel.checkoutPreference.id
		} else {
			properties["checkout_preference"] = viewModel.checkoutPreference.getCheckoutPrefForTracking()
		}
		
		properties["esc_enabled"] = viewModel.getAdvancedConfiguration().escEnabled
		properties["express_enabled"] = viewModel.getAdvancedConfiguration().expressEnabled
		
		viewModel.populateCheckoutStore()
		properties["split_enabled"] = viewModel.paymentPlugin?.supportSplitPaymentMethodPayment(checkoutStore: PXCheckoutStore.sharedInstance)
		
		MPXTracker.sharedInstance.trackEvent(path: TrackingPaths.Events.getInitPath(), properties: properties)
	}
}


// swiftlint:disable function_parameter_count
internal class MercadoPagoServicesAdapter {
	
	let mercadoPagoServices: MercadoPagoServices!
	
	init(publicKey: String, privateKey: String?) {
		mercadoPagoServices = MercadoPagoServices(merchantPublicKey: publicKey, payerAccessToken: privateKey ?? "")
		mercadoPagoServices.setLanguage(language: Localizator.sharedInstance.getLanguage())
	}
	
	func update(processingModes: [String]?, branchId: String? = nil) {
		mercadoPagoServices.update(processingModes: processingModes ?? PXServicesURLConfigs.MP_DEFAULT_PROCESSING_MODES)
		if let branchId = branchId {
			mercadoPagoServices.update(branchId: branchId)
		}
	}
	
	func getTimeOut() -> TimeInterval {
		return 15.0
	}
	
	func getInstructions(paymentId: String, paymentTypeId: String, callback : @escaping (PXInstructions) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		
		let int64PaymentId = Int64(paymentId) //TODO: FIX
		
		mercadoPagoServices.getInstructions(paymentId: int64PaymentId!, paymentTypeId: paymentTypeId, callback: { (pxInstructions) in
			callback(pxInstructions)
		}, failure: failure)
	}
	
	typealias PaymentSearchExclusions = (excludedPaymentTypesIds: [String], excludedPaymentMethodsIds: [String])
	typealias ExtraParams = (defaultPaymentMethod: String?, differentialPricingId: String?, defaultInstallments: String?, expressEnabled: Bool, hasPaymentProcessor: Bool, splitEnabled: Bool, maxInstallments: String?)
	
	func getOpenPrefInitSearch(preference: PXCheckoutPreference, cardIdsWithEsc: [String], extraParams: ExtraParams?, discountParamsConfiguration: PXDiscountParamsConfiguration?, flow: String?, charges: [PXPaymentTypeChargeRule], headers: [String: String]?, callback : @escaping (PXInitDTO) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		
		let oneTapEnabled: Bool = extraParams?.expressEnabled ?? false
		let splitEnabled: Bool = extraParams?.splitEnabled ?? false
		
		mercadoPagoServices.getOpenPrefInitSearch(pref: preference, cardsWithEsc: cardIdsWithEsc, oneTapEnabled: oneTapEnabled, splitEnabled: splitEnabled, discountParamsConfiguration: discountParamsConfiguration, flow: flow, charges: charges, headers: headers, callback: { (pxPaymentMethodSearch) in
			callback(pxPaymentMethodSearch)
		}, failure: failure)
	}
	
	func getClosedPrefInitSearch(preferenceId: String, cardIdsWithEsc: [String], extraParams: ExtraParams?, discountParamsConfiguration: PXDiscountParamsConfiguration?, flow: String?, charges: [PXPaymentTypeChargeRule], headers: [String: String]?, callback : @escaping (PXInitDTO) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		
		let oneTapEnabled: Bool = extraParams?.expressEnabled ?? false
		let splitEnabled: Bool = extraParams?.splitEnabled ?? false
		
		mercadoPagoServices.getClosedPrefInitSearch(preferenceId: preferenceId, cardsWithEsc: cardIdsWithEsc, oneTapEnabled: oneTapEnabled, splitEnabled: splitEnabled, discountParamsConfiguration: discountParamsConfiguration, flow: flow, charges: charges, headers: headers, callback: { (pxPaymentMethodSearch) in
			callback(pxPaymentMethodSearch)
		}, failure: failure)
	}
	
	func createPayment(url: String, uri: String, transactionId: String? = nil, paymentDataJSON: Data, query: [String: String]? = nil, headers: [String: String]? = nil, callback : @escaping (PXPayment) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		
		mercadoPagoServices.createPayment(url: url, uri: uri, transactionId: transactionId, paymentDataJSON: paymentDataJSON, query: query, headers: headers, callback: { (pxPayment) in
			callback(pxPayment)
		}, failure: failure)
	}
	
	func getPointsAndDiscounts(url: String, uri: String, paymentIds: [String]? = nil, campaignId: String?, platform: String, callback : @escaping (PXPointsAndDiscounts) -> Void, failure: @escaping (() -> Void)) {
		
		mercadoPagoServices.getPointsAndDiscounts(url: url, uri: uri, paymentIds: paymentIds, campaignId: campaignId, platform: platform, callback: callback, failure: failure)
	}
	
	func createToken(cardToken: PXCardToken, callback : @escaping (PXToken) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		
		mercadoPagoServices.createToken(cardToken: cardToken, callback: { (pxToken) in
			callback(pxToken)
		}, failure: failure)
	}
	
	func createToken(savedESCCardToken: PXSavedESCCardToken, callback : @escaping (PXToken) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		
		mercadoPagoServices.createToken(savedESCCardToken: savedESCCardToken, callback: { (pxToken) in
			callback(pxToken)
		}, failure: failure)
	}
	
	func createToken(savedCardToken: PXSavedCardToken, callback : @escaping (PXToken) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		mercadoPagoServices.createToken(savedCardToken: savedCardToken, callback: { (pxToken) in
			callback(pxToken)
		}, failure: failure)
	}
	
	func createToken(cardToken: Data, callback : @escaping (PXToken) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		mercadoPagoServices.createToken(cardToken: cardToken, callback: { (pxToken) in
			callback(pxToken)
		}, failure: failure)
	}
	
	func cloneToken(tokenId: String, securityCode: String, callback : @escaping (PXToken) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		mercadoPagoServices.cloneToken(tokenId: tokenId, securityCode: securityCode, callback: { (pxToken) in
			callback(pxToken)
		}, failure: failure)
	}
	
	func getBankDeals(callback : @escaping ([PXBankDeal]) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		mercadoPagoServices.getBankDeals(callback: callback, failure: failure)
	}
	
	func getIdentificationTypes(callback: @escaping ([PXIdentificationType]) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		mercadoPagoServices.getIdentificationTypes(callback: { (pxIdentificationTypes) in
			callback(pxIdentificationTypes)
		}, failure: failure)
	}
	
	func getIssuers(paymentMethodId: String, bin: String? = nil, callback: @escaping ([PXIssuer]) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		
		mercadoPagoServices.getIssuers(paymentMethodId: paymentMethodId, bin: bin, callback: { (pxIssuers) in
			callback(pxIssuers)
		}, failure: failure)
	}
	
	func createSerializationError(requestOrigin: ApiUtil.RequestOrigin) -> NSError {
		#if DEBUG
		print("--REQUEST_ERROR: Cannot serlialize data in \(requestOrigin.rawValue)\n")
		#endif
		
		return NSError(domain: "com.mercadopago.sdk", code: NSURLErrorCannotDecodeContentData, userInfo: [NSLocalizedDescriptionKey: "Hubo un error"])
	}
	
	open func getSummaryAmount(bin: String?, amount: Double, issuer: PXIssuer?, paymentMethodId: String, payment_type_id: String, differentialPricingId: String?, siteId: String?, marketplace: String?, discountParamsConfiguration: PXDiscountParamsConfiguration?, payer: PXPayer, defaultInstallments: Int?, charges: [PXPaymentTypeChargeRule]?, maxInstallments: Int?, callback: @escaping (PXSummaryAmount) -> Void, failure: @escaping ((_ error: NSError) -> Void)) {
		
		mercadoPagoServices.getSummaryAmount(bin: bin, amount: amount, issuerId: issuer?.id, paymentMethodId: paymentMethodId, payment_type_id: payment_type_id, differentialPricingId: differentialPricingId, siteId: siteId, marketplace: marketplace, discountParamsConfiguration: discountParamsConfiguration, payer: payer, defaultInstallments: defaultInstallments, charges: charges, maxInstallments: maxInstallments, callback: { (summaryAmount) in
			callback(summaryAmount)
		}, failure: failure)
	}
}
