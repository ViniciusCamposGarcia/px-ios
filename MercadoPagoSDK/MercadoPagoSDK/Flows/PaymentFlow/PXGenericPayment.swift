//
//  PXGenericPayment.swift
//  MercadoPagoSDK
//
//  Created by Eden Torres on 26/06/2018.
//  Copyright © 2018 MercadoPago. All rights reserved.
//

import Foundation

/**
 Use this object to notify your own custom payment using `PXPaymentProcessor`.
 */
@objcMembers
open class PXGenericPayment: NSObject, PXBasePayment {

    public func getPaymentMethodId() -> String? {
        return paymentMethodId
    }

    public func getPaymentMethodTypeId() -> String? {
        return paymentMethodTypeId
    }

    public func getPaymentId() -> String? {
        return paymentId
    }
    public func getStatus() -> String {
        return status
    }

    public func getStatusDetail() -> String {
        return statusDetail
    }

    /// :nodoc:
    @objc public enum RemotePaymentStatus: Int {
        case APPROVED
        case REJECTED
    }

    // MARK: Public accessors.
    /**
     id related to your payment.
     */
    public let paymentId: String?

    /**
     Status of your payment.
     */
    public let status: String

    /**
     Status detail of your payment.
     */
    public let statusDetail: String

    /**
     Payment method type id.
     */
    public let paymentMethodId: String?

    /**
     Payment method type id.
     */
    public let paymentMethodTypeId: String?

    // MARK: Init.
    /**
     - parameter status: Status of payment.
     - parameter statusDetail: Status detail of payment.
     - parameter paymentId: Id of payment.
     */
    @available(*, deprecated: 4.7.0, message: "Use init with payment method id")
    public init(status: String, statusDetail: String, paymentId: String? = nil) {
        self.status = status
        self.statusDetail = statusDetail
        self.paymentId = paymentId
        self.paymentMethodId = nil
        self.paymentMethodTypeId = nil
    }

    /// :nodoc:
    public init(paymentStatus: PXGenericPayment.RemotePaymentStatus, statusDetail: String, receiptId: String? = nil) {
        var paymentStatusStrDefault = PXPaymentStatus.REJECTED.rawValue

        if paymentStatus == .APPROVED {
            paymentStatusStrDefault = PXPaymentStatus.APPROVED.rawValue
        }
        self.status = paymentStatusStrDefault
        self.statusDetail = statusDetail
        self.paymentId = receiptId
        self.paymentMethodId = nil
        self.paymentMethodTypeId = nil
    }

    // MARK: Init.
    /**
     - parameter status: Status of payment.
     - parameter statusDetail: Status detail of payment.
     - parameter paymentId: Id of payment.
     - parameter paymentMethodId: Payment Method id.
     - parameter paymentMethodTypeId: Payment Type Id.
     */
    public init(status: String, statusDetail: String, paymentId: String? = nil, paymentMethodId: String?, paymentMethodTypeId: String?) {
        self.status = status
        self.statusDetail = statusDetail
        self.paymentId = paymentId
        self.paymentMethodId = paymentMethodId
        self.paymentMethodTypeId = paymentMethodTypeId
    }
}

internal protocol PaymentHandlerProtocol {
	func handlePayment(payment: PXPayment)
	func handlePayment(business: PXBusinessResult)
	func handlePayment(basePayment: PXBasePayment)
}

@objc internal protocol PXPaymentErrorHandlerProtocol: NSObjectProtocol {
	func escError()
	func exitCheckout()
	@objc optional func identificationError()
}

internal final class PXPaymentFlow: NSObject, PXFlow {
	let model: PXPaymentFlowModel
	weak var resultHandler: PXPaymentResultHandlerProtocol?
	weak var paymentErrorHandler: PXPaymentErrorHandlerProtocol?
	
	var pxNavigationHandler: PXNavigationHandler
	
	init(paymentPlugin: PXSplitPaymentProcessor?, mercadoPagoServicesAdapter: MercadoPagoServicesAdapter, paymentErrorHandler: PXPaymentErrorHandlerProtocol, navigationHandler: PXNavigationHandler, amountHelper: PXAmountHelper, checkoutPreference: PXCheckoutPreference?, escManager: MercadoPagoESC?) {
		model = PXPaymentFlowModel(paymentPlugin: paymentPlugin, mercadoPagoServicesAdapter: mercadoPagoServicesAdapter, escManager: escManager)
		self.paymentErrorHandler = paymentErrorHandler
		self.pxNavigationHandler = navigationHandler
		self.model.amountHelper = amountHelper
		self.model.checkoutPreference = checkoutPreference
	}
	
	func setData(amountHelper: PXAmountHelper, checkoutPreference: PXCheckoutPreference, resultHandler: PXPaymentResultHandlerProtocol) {
		self.model.amountHelper = amountHelper
		self.model.checkoutPreference = checkoutPreference
		self.resultHandler = resultHandler
		
		if let discountToken = amountHelper.paymentConfigurationService.getAmountConfigurationForPaymentMethod(amountHelper.getPaymentData().token?.cardId)?.discountToken, amountHelper.splitAccountMoney == nil {
			self.model.amountHelper?.getPaymentData().discount?.id = discountToken.stringValue
			self.model.amountHelper?.getPaymentData().campaign?.id = discountToken
		}
	}
	
	func setProductIdForPayment(_ productId: String) {
		model.productId = productId
	}
	
	deinit {
		#if DEBUG
		print("DEINIT FLOW - \(self)")
		#endif
	}
	
	func start() {
		executeNextStep()
	}
	
	func executeNextStep() {
		switch self.model.nextStep() {
		case .createDefaultPayment:
			createPayment()
		case .createPaymentPlugin:
			createPaymentWithPlugin(plugin: model.paymentPlugin)
		case .createPaymentPluginScreen:
			showPaymentProcessor(paymentProcessor: model.paymentPlugin)
		case .getPointsAndDiscounts:
			getPointsAndDiscounts()
		case .getInstructions:
			getInstructions()
		case .finish:
			finishFlow()
		}
	}
	
	func getPaymentTimeOut() -> TimeInterval {
		let instructionTimeOut: TimeInterval = model.isOfflinePayment() ? 15 : 0
		if let paymentPluginTimeOut = model.paymentPlugin?.paymentTimeOut?(), paymentPluginTimeOut > 0 {
			return paymentPluginTimeOut + instructionTimeOut
		} else {
			return model.mercadoPagoServicesAdapter.getTimeOut() + instructionTimeOut
		}
	}
	
	func needToShowPaymentPluginScreen() -> Bool {
		return model.needToShowPaymentPluginScreenForPaymentPlugin()
	}
	
	func hasPaymentPluginScreen() -> Bool {
		return model.hasPluginPaymentScreen()
	}
	
	func finishFlow() {
		if let paymentResult = model.paymentResult {
			self.resultHandler?.finishPaymentFlow(paymentResult: (paymentResult), instructionsInfo: model.instructionsInfo, pointsAndDiscounts: model.pointsAndDiscounts)
			return
		} else if let businessResult = model.businessResult {
			self.resultHandler?.finishPaymentFlow(businessResult: businessResult, pointsAndDiscounts: model.pointsAndDiscounts)
			return
		}
	}
	
	func cancelFlow() {}
	
	func exitCheckout() {}
	
	func cleanPayment() {
		model.cleanData()
	}
}

/** :nodoc: */
extension PXPaymentFlow: PXPaymentProcessorErrorHandler {
	func showError() {
		let error = MPSDKError(message: "Hubo un error".localized, errorDetail: "", retry: false)
		error.requestOrigin = ApiUtil.RequestOrigin.CREATE_PAYMENT.rawValue
		resultHandler?.finishPaymentFlow(error: error)
	}
	
	func showError(error: MPSDKError) {
		resultHandler?.finishPaymentFlow(error: error)
	}
}


// MARK: PaymentHandlerProtocol implementation
extension PXPaymentFlow: PaymentHandlerProtocol {
	func handlePayment(payment: PXPayment) {
		guard let paymentData = self.model.amountHelper?.getPaymentData() else {
			return
		}
		
		self.model.handleESCForPayment(status: payment.status, statusDetails: payment.statusDetail, errorPaymentType: payment.getPaymentMethodTypeId())
		
		if payment.getStatusDetail() == PXRejectedStatusDetail.INVALID_ESC.rawValue {
			self.paymentErrorHandler?.escError()
			return
		}
		
		let paymentResult = PaymentResult(payment: payment, paymentData: paymentData)
		self.model.paymentResult = paymentResult
		self.executeNextStep()
	}
	
	func handlePayment(business: PXBusinessResult) {
		self.model.businessResult = business
		self.model.handleESCForPayment(status: business.paymentStatus, statusDetails: business.paymentStatusDetail, errorPaymentType: business.getPaymentMethodTypeId())
		self.executeNextStep()
	}
	
	func handlePayment(basePayment: PXBasePayment) {
		if let business = basePayment as? PXBusinessResult {
			handlePayment(business: business)
		} else if let payment = basePayment as? PXPayment {
			handlePayment(basePayment: payment)
		} else {
			guard let paymentData = self.model.amountHelper?.getPaymentData() else {
				return
			}
			
			self.model.handleESCForPayment(status: basePayment.getStatus(), statusDetails: basePayment.getStatusDetail(), errorPaymentType: basePayment.getPaymentMethodTypeId())
			
			if basePayment.getStatusDetail() == PXRejectedStatusDetail.INVALID_ESC.rawValue {
				self.paymentErrorHandler?.escError()
				return
			}
			
			let paymentResult = PaymentResult(status: basePayment.getStatus(), statusDetail: basePayment.getStatusDetail(), paymentData: paymentData, splitAccountMoney: self.model.amountHelper?.splitAccountMoney, payerEmail: nil, paymentId: basePayment.getPaymentId(), statementDescription: nil, paymentMethodId: basePayment.getPaymentMethodId(), paymentMethodTypeId: basePayment.getPaymentMethodTypeId())
			self.model.paymentResult = paymentResult
			self.executeNextStep()
		}
	}
}


extension PXPaymentFlow {
	internal func showPaymentProcessor(paymentProcessor: PXSplitPaymentProcessor?) {
		guard let paymentProcessor = paymentProcessor else {
			return
		}
		
		model.assignToCheckoutStore()
		
		paymentProcessor.didReceive?(navigationHandler: PXPaymentProcessorNavigationHandler(flow: self))
		
		if let paymentProcessorVC = paymentProcessor.paymentProcessorViewController() {
			pxNavigationHandler.addDynamicView(viewController: paymentProcessorVC)
			
			if let shouldSkipRyC = paymentProcessor.shouldSkipUserConfirmation?(), shouldSkipRyC, pxNavigationHandler.isLoadingPresented() {
				pxNavigationHandler.dismissLoading()
			}
			pxNavigationHandler.navigationController.pushViewController(paymentProcessorVC, animated: false)
		}
	}
}


internal extension PXPaymentFlow {
	func createPaymentWithPlugin(plugin: PXSplitPaymentProcessor?) {
		guard let plugin = plugin else {
			return
		}
		
		plugin.didReceive?(checkoutStore: PXCheckoutStore.sharedInstance)
		
		plugin.startPayment?(checkoutStore: PXCheckoutStore.sharedInstance, errorHandler: self as PXPaymentProcessorErrorHandler, successWithBasePayment: { [weak self] (basePayment) in
			self?.handlePayment(basePayment: basePayment)
		})
	}
	
	func createPayment() {
		guard let _ = model.amountHelper?.getPaymentData(), let _ = model.checkoutPreference else {
			return
		}
		
		model.assignToCheckoutStore()
		guard let paymentBody = (try? JSONEncoder().encode(PXCheckoutStore.sharedInstance)) else {
			fatalError("Cannot make payment json body")
		}
		
		var headers: [String: String] = [:]
		if let productId = model.productId {
			headers[MercadoPagoService.HeaderField.productId.rawValue] = productId
		}
		
		headers[MercadoPagoService.HeaderField.idempotencyKey.rawValue] =  model.generateIdempotecyKey()
		
		model.mercadoPagoServicesAdapter.createPayment(url: PXServicesURLConfigs.MP_API_BASE_URL, uri: PXServicesURLConfigs.MP_PAYMENTS_URI, paymentDataJSON: paymentBody, query: nil, headers: headers, callback: { (payment) in
			self.handlePayment(payment: payment)
			
		}, failure: { [weak self] (error) in
			
			let mpError = MPSDKError.convertFrom(error, requestOrigin: ApiUtil.RequestOrigin.CREATE_PAYMENT.rawValue)
			
			// ESC error
			if let apiException = mpError.apiException, apiException.containsCause(code: ApiUtil.ErrorCauseCodes.INVALID_PAYMENT_WITH_ESC.rawValue) {
				self?.paymentErrorHandler?.escError()
				
				// Identification number error
			} else if let apiException = mpError.apiException, apiException.containsCause(code: ApiUtil.ErrorCauseCodes.INVALID_PAYMENT_IDENTIFICATION_NUMBER.rawValue) {
				self?.paymentErrorHandler?.identificationError?()
				
			} else {
				self?.showError(error: mpError)
			}
			
		})
	}
	
	func getPointsAndDiscounts() {
		
		var paymentIds = [String]()
		if let paymentResultId = model.paymentResult?.paymentId {
			paymentIds.append(paymentResultId)
		} else if let businessResult = model.businessResult {
			if let receiptLists = businessResult.getReceiptIdList() {
				paymentIds = receiptLists
			} else if let receiptId = businessResult.getReceiptId() {
				paymentIds.append(receiptId)
			}
		}
		
		let campaignId: String? = model.amountHelper?.campaign?.id?.stringValue
		
		model.shouldSearchPointsAndDiscounts = false
		let platform = MLBusinessAppDataService().getAppIdentifier().rawValue
		model.mercadoPagoServicesAdapter.getPointsAndDiscounts(url: PXServicesURLConfigs.MP_API_BASE_URL, uri: PXServicesURLConfigs.MP_POINTS_URI, paymentIds: paymentIds, campaignId: campaignId, platform: platform, callback: { [weak self] (pointsAndBenef) in
			guard let strongSelf = self else { return }
			strongSelf.model.pointsAndDiscounts = pointsAndBenef
			strongSelf.executeNextStep()
			}, failure: { [weak self] () in
				print("Fallo el endpoint de puntos y beneficios")
				guard let strongSelf = self else { return }
				strongSelf.executeNextStep()
		})
	}
	
	func getInstructions() {
		guard let paymentResult = model.paymentResult else {
			fatalError("Get Instructions - Payment Result does no exist")
		}
		
		guard let paymentId = paymentResult.paymentId else {
			fatalError("Get Instructions - Payment Id does no exist")
		}
		
		guard let paymentTypeId = paymentResult.paymentData?.getPaymentMethod()?.paymentTypeId else {
			fatalError("Get Instructions - Payment Method Type Id does no exist")
		}
		
		model.mercadoPagoServicesAdapter.getInstructions(paymentId: paymentId, paymentTypeId: paymentTypeId, callback: { [weak self] (instructions) in
			self?.model.instructionsInfo = instructions
			self?.executeNextStep()
			
			}, failure: {[weak self] (error) in
				
				let mpError = MPSDKError.convertFrom(error, requestOrigin: ApiUtil.RequestOrigin.GET_INSTRUCTIONS.rawValue)
				self?.showError(error: mpError)
				
		})
	}
}


internal final class PXPaymentFlowModel: NSObject {
	var amountHelper: PXAmountHelper?
	var checkoutPreference: PXCheckoutPreference?
	let paymentPlugin: PXSplitPaymentProcessor?
	
	let mercadoPagoServicesAdapter: MercadoPagoServicesAdapter
	
	var paymentResult: PaymentResult?
	var instructionsInfo: PXInstructions?
	var pointsAndDiscounts: PXPointsAndDiscounts?
	var businessResult: PXBusinessResult?
	
	let escManager: MercadoPagoESC?
	var productId: String?
	var shouldSearchPointsAndDiscounts: Bool = true
	
	init(paymentPlugin: PXSplitPaymentProcessor?, mercadoPagoServicesAdapter: MercadoPagoServicesAdapter, escManager: MercadoPagoESC?) {
		self.paymentPlugin = paymentPlugin
		self.mercadoPagoServicesAdapter = mercadoPagoServicesAdapter
		self.escManager = escManager
	}
	
	enum Steps: String {
		case createPaymentPlugin
		case createDefaultPayment
		case getPointsAndDiscounts
		case getInstructions
		case createPaymentPluginScreen
		case finish
	}
	
	func nextStep() -> Steps {
		if needToCreatePaymentForPaymentPlugin() {
			return .createPaymentPlugin
		} else if needToShowPaymentPluginScreenForPaymentPlugin() {
			return .createPaymentPluginScreen
		} else if needToCreatePayment() {
			return .createDefaultPayment
		} else if needToGetPointsAndDiscounts() {
			return .getPointsAndDiscounts
		} else if needToGetInstructions() {
			return .getInstructions
		} else {
			return .finish
		}
	}
	
	func needToCreatePaymentForPaymentPlugin() -> Bool {
		if paymentPlugin == nil {
			return false
		}
		
		if !needToCreatePayment() {
			return false
		}
		
		if hasPluginPaymentScreen() {
			return false
		}
		
		assignToCheckoutStore()
		paymentPlugin?.didReceive?(checkoutStore: PXCheckoutStore.sharedInstance)
		
		if let shouldSupport = paymentPlugin?.support() {
			return shouldSupport
		}
		
		return false
	}
	
	func needToCreatePayment() -> Bool {
		return paymentResult == nil && businessResult == nil
	}
	
	func needToGetPointsAndDiscounts() -> Bool {
		if let paymentResult = paymentResult, shouldSearchPointsAndDiscounts, (paymentResult.isApproved() || needToGetInstructions()) {
			return true
		} else if let businessResult = businessResult, shouldSearchPointsAndDiscounts, businessResult.isApproved() {
			return true
		}
		return false
	}
	
	func needToGetInstructions() -> Bool {
		guard let paymentResult = self.paymentResult else {
			return false
		}
		
		guard !String.isNullOrEmpty(paymentResult.paymentId) else {
			return false
		}
		
		return isOfflinePayment() && instructionsInfo == nil
	}
	
	func needToShowPaymentPluginScreenForPaymentPlugin() -> Bool {
		if !needToCreatePayment() {
			return false
		}
		return hasPluginPaymentScreen()
	}
	
	func isOfflinePayment() -> Bool {
		guard let paymentTypeId = amountHelper?.getPaymentData().paymentMethod?.paymentTypeId else {
			return false
		}
		return !PXPaymentTypes.isOnlineType(paymentTypeId: paymentTypeId)
	}
	
	func assignToCheckoutStore() {
		if let amountHelper = amountHelper {
			PXCheckoutStore.sharedInstance.paymentDatas = [amountHelper.getPaymentData()]
			if let splitAccountMoney = amountHelper.splitAccountMoney {
				PXCheckoutStore.sharedInstance.paymentDatas.append(splitAccountMoney)
			}
		}
		PXCheckoutStore.sharedInstance.checkoutPreference = checkoutPreference
	}
	
	func cleanData() {
		paymentResult = nil
		businessResult = nil
		instructionsInfo = nil
	}
}

internal extension PXPaymentFlowModel {
	func hasPluginPaymentScreen() -> Bool {
		guard let paymentPlugin = paymentPlugin else {
			return false
		}
		assignToCheckoutStore()
		paymentPlugin.didReceive?(checkoutStore: PXCheckoutStore.sharedInstance)
		let processorViewController = paymentPlugin.paymentProcessorViewController()
		return processorViewController != nil
	}
}

// MARK: Manage ESC
internal extension PXPaymentFlowModel {
	func handleESCForPayment(status: String, statusDetails: String, errorPaymentType: String?) {
		guard let token = amountHelper?.getPaymentData().getToken() else {
			return
		}
		let isApprovedPayment: Bool = status == PXPaymentStatus.APPROVED.rawValue
		
		if !isApprovedPayment {
			if token.hasCardId() {
				guard let errorPaymentType = errorPaymentType else {
					escManager?.deleteESC(cardId: token.cardId)
					return
				}
				// If it has error Payment Type, check if the error was from a card
				if let isCard = PXPaymentTypes(rawValue: errorPaymentType)?.isCard(), isCard {
					escManager?.deleteESC(cardId: token.cardId)
				}
			} else {
				// Case if it's a new card
				guard let errorPaymentType = errorPaymentType else {
					escManager?.deleteESC(firstSixDigits: token.firstSixDigits, lastFourDigits: token.lastFourDigits)
					return
				}
				// If it has error Payment Type, check if the error was from a card
				if let isCard = PXPaymentTypes(rawValue: errorPaymentType)?.isCard(), isCard {
					escManager?.deleteESC(firstSixDigits: token.firstSixDigits, lastFourDigits: token.lastFourDigits)
				}
			}
		} else if let esc = token.esc {
			// If payment was approved
			if token.hasCardId() {
				escManager?.saveESC(cardId: token.cardId, esc: esc)
			} else {
				escManager?.saveESC(firstSixDigits: token.firstSixDigits, lastFourDigits: token.lastFourDigits, esc: esc)
			}
		}
	}
}

extension PXPaymentFlowModel {
	func generateIdempotecyKey() -> String {
		return String(arc4random()) + String(Date().timeIntervalSince1970)
	}
}
