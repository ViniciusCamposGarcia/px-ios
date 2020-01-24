//
//  InitFlow.swift
//  MercadoPagoSDK
//
//  Created by Juan sebastian Sanzone on 26/6/18.
//  Copyright © 2018 MercadoPago. All rights reserved.
//

import Foundation

final class InitFlow {
    let initFlowModel: InitFlowModel

    private var status: PXFlowStatus = .ready
    private let finishInitCallback: ((PXCheckoutPreference, PXInitDTO) -> Void)
    private let errorInitCallback: ((InitFlowError) -> Void)

    init(flowProperties: InitFlowProperties, finishInitCallback: @escaping ((PXCheckoutPreference, PXInitDTO) -> Void), errorInitCallback: @escaping ((InitFlowError) -> Void)) {
        self.finishInitCallback = finishInitCallback
        self.errorInitCallback = errorInitCallback
        initFlowModel = InitFlowModel(flowProperties: flowProperties)
        PXTrackingStore.sharedInstance.cleanChoType()
    }

    func updateModel(paymentPlugin: PXSplitPaymentProcessor?, paymentMethodPlugins: [PXPaymentMethodPlugin]?, chargeRules: [PXPaymentTypeChargeRule]?) {
        var pmPlugins: [PXPaymentMethodPlugin] = [PXPaymentMethodPlugin]()
        if let targetPlugins = paymentMethodPlugins {
            pmPlugins = targetPlugins
        }
        initFlowModel.update(paymentPlugin: paymentPlugin, paymentMethodPlugins: pmPlugins, chargeRules: chargeRules)
    }

    deinit {
        #if DEBUG
            print("DEINIT FLOW - \(self)")
        #endif
    }
}

extension InitFlow: PXFlow {
    func start() {
        if status != .running {
            status = .running
            executeNextStep()
        }
    }

    func executeNextStep() {
        let nextStep = initFlowModel.nextStep()
        switch nextStep {
        case .SERVICE_GET_INIT:
            getInitSearch()
        case .FINISH:
            finishFlow()
        case .ERROR:
            cancelFlow()
        }
    }

    func finishFlow() {
        status = .finished
        if let paymentMethodsSearch = initFlowModel.getPaymentMethodSearch() {
            setCheckoutTypeForTracking()

            //Return the preference we retrieved or the one the integrator created
            let preference = paymentMethodsSearch.preference ?? initFlowModel.properties.checkoutPreference
            finishInitCallback(preference, paymentMethodsSearch)
        } else {
            cancelFlow()
        }
    }

    func cancelFlow() {
        status = .finished
        errorInitCallback(initFlowModel.getError())
        initFlowModel.resetError()
    }

    func exitCheckout() {}
}

// MARK: - Getters
extension InitFlow {
    func setFlowRetry(step: InitFlowModel.Steps) {
        status = .ready
        initFlowModel.setPendingRetry(forStep: step)
    }

    func disposePendingRetry() {
        initFlowModel.removePendingRetry()
    }

    func getStatus() -> PXFlowStatus {
        return status
    }

    func restart() {
        if status != .running {
            status = .ready
        }
    }
}

// MARK: - Privates
extension InitFlow {
    private func setCheckoutTypeForTracking() {
        if let paymentMethodsSearch = initFlowModel.getPaymentMethodSearch() {
            PXTrackingStore.sharedInstance.setChoType(paymentMethodsSearch.oneTap != nil ? .one_tap : .traditional)
        }
    }
}

extension InitFlow {
	
	func getInitSearch() {
		let cardIdsWithEsc = initFlowModel.getESCService()?.getSavedCardIds() ?? []
		
		var differentialPricingString: String?
		if let diffPricing = initFlowModel.properties.checkoutPreference.differentialPricing?.id {
			differentialPricingString = String(describing: diffPricing)
		}
		
		var defaultInstallments: String?
		let dInstallments = initFlowModel.properties.checkoutPreference.getDefaultInstallments()
		if let dInstallments = dInstallments {
			defaultInstallments = String(dInstallments)
		}
		
		var maxInstallments: String?
		let mInstallments = initFlowModel.properties.checkoutPreference.getMaxAcceptedInstallments()
		maxInstallments = String(mInstallments)
		
		let hasPaymentProcessor: Bool = initFlowModel.properties.paymentPlugin != nil ? true : false
		let discountParamsConfiguration = initFlowModel.properties.advancedConfig.discountParamsConfiguration
		let flowName: String? = MPXTracker.sharedInstance.getFlowName() ?? nil
		let splitEnabled: Bool = initFlowModel.properties.paymentPlugin?.supportSplitPaymentMethodPayment(checkoutStore: PXCheckoutStore.sharedInstance) ?? false
		let serviceAdapter = initFlowModel.getService()
		
		//payment method search service should be performed using the processing modes designated by the preference object
		let pref = initFlowModel.properties.checkoutPreference
		serviceAdapter.update(processingModes: pref.processingModes, branchId: pref.branchId)
		
		let extraParams = (defaultPaymentMethod: initFlowModel.getDefaultPaymentMethodId(), differentialPricingId: differentialPricingString, defaultInstallments: defaultInstallments, expressEnabled: initFlowModel.properties.advancedConfig.expressEnabled, hasPaymentProcessor: hasPaymentProcessor, splitEnabled: splitEnabled, maxInstallments: maxInstallments)
		
		let charges = self.initFlowModel.amountHelper.chargeRules ?? []
		
		//Add headers
		var headers: [String: String] = [:]
		if let prodId = initFlowModel.properties.productId {
			headers[MercadoPagoService.HeaderField.productId.rawValue] = prodId
		}
		
		if let prefId = pref.id, prefId.isNotEmpty {
			// CLOSED PREFERENCE
			serviceAdapter.getClosedPrefInitSearch(preferenceId: prefId, cardIdsWithEsc: cardIdsWithEsc, extraParams: extraParams, discountParamsConfiguration: discountParamsConfiguration, flow: flowName, charges: charges, headers: headers, callback: callback(_:), failure: failure(_:))
		} else {
			// OPEN PREFERENCE
			serviceAdapter.getOpenPrefInitSearch(preference: pref, cardIdsWithEsc: cardIdsWithEsc, extraParams: extraParams, discountParamsConfiguration: discountParamsConfiguration, flow: flowName, charges: charges, headers: headers, callback: callback(_:), failure: failure(_:))
		}
	}
	
	func callback(_ search: PXInitDTO) {
		initFlowModel.updateInitModel(paymentMethodsResponse: search)
		
		//Tracking Experiments
		MPXTracker.sharedInstance.setExperiments(search.experiments)
		
		//Set site
		SiteManager.shared.setCurrency(currency: search.currency)
		SiteManager.shared.setSite(site: search.site)
		
		executeNextStep()
	}
	
	func failure(_ error: NSError) {
		let customError = InitFlowError(errorStep: .SERVICE_GET_INIT, shouldRetry: true, requestOrigin: .GET_INIT, apiException: MPSDKError.getApiException(error))
		initFlowModel.setError(error: customError)
		executeNextStep()
	}
}

internal typealias InitFlowProperties = (paymentData: PXPaymentData, checkoutPreference: PXCheckoutPreference, paymentPlugin: PXSplitPaymentProcessor?, paymentMethodPlugins: [PXPaymentMethodPlugin], paymentMethodSearchResult: PXInitDTO?, chargeRules: [PXPaymentTypeChargeRule]?, serviceAdapter: MercadoPagoServicesAdapter, advancedConfig: PXAdvancedConfiguration, paymentConfigurationService: PXPaymentConfigurationServices, escManager: MercadoPagoESC?, privateKey: String?, productId: String?)
internal typealias InitFlowError = (errorStep: InitFlowModel.Steps, shouldRetry: Bool, requestOrigin: ApiUtil.RequestOrigin?, apiException: ApiException?)

internal protocol InitFlowProtocol: NSObjectProtocol {
	func didFinishInitFlow()
	func didFailInitFlow(flowError: InitFlowError)
}

final class InitFlowModel: NSObject, PXFlowModel {
	enum Steps: String {
		case ERROR = "Error"
		case SERVICE_GET_INIT = "Obtener preferencia y medios de pago"
		case FINISH = "Finish step"
	}
	
	private var preferenceValidated: Bool = false
	private var needPaymentMethodPluginInit = true
	private var directDiscountSearchStatus: Bool
	private var flowError: InitFlowError?
	private var pendingRetryStep: Steps?
	
	var properties: InitFlowProperties
	
	var amountHelper: PXAmountHelper {
		get {
			return PXAmountHelper(preference: self.properties.checkoutPreference, paymentData: self.properties.paymentData, chargeRules: self.properties.chargeRules, paymentConfigurationService: self.properties.paymentConfigurationService, splitAccountMoney: nil)
		}
	}
	
	init(flowProperties: InitFlowProperties) {
		self.properties = flowProperties
		self.directDiscountSearchStatus = flowProperties.paymentData.isComplete()
		super.init()
	}
	
	func update(paymentPlugin: PXSplitPaymentProcessor?, paymentMethodPlugins: [PXPaymentMethodPlugin], chargeRules: [PXPaymentTypeChargeRule]?) {
		properties.paymentPlugin = paymentPlugin
		properties.paymentMethodPlugins = paymentMethodPlugins
		properties.chargeRules = chargeRules
	}
}

// MARK: Public methods
extension InitFlowModel {
	func getService() -> MercadoPagoServicesAdapter {
		return properties.serviceAdapter
	}
	
	func getESCService() -> MercadoPagoESC? {
		return properties.escManager
	}
	
	func getError() -> InitFlowError {
		if let error = flowError {
			return error
		}
		return InitFlowError(errorStep: .ERROR, shouldRetry: false, requestOrigin: nil, apiException: nil)
	}
	
	func setError(error: InitFlowError) {
		flowError = error
	}
	
	func resetError() {
		flowError = nil
	}
	
	func setPendingRetry(forStep: Steps) {
		pendingRetryStep = forStep
	}
	
	func removePendingRetry() {
		pendingRetryStep = nil
	}
	
	func paymentMethodPluginDidLoaded() {
		needPaymentMethodPluginInit = false
	}
	
	func getExcludedPaymentTypesIds() -> [String] {
		if properties.checkoutPreference.siteId == "MLC" || properties.checkoutPreference.siteId == "MCO" ||
			properties.checkoutPreference.siteId == "MLV" {
			properties.checkoutPreference.addExcludedPaymentType("atm")
			properties.checkoutPreference.addExcludedPaymentType("bank_transfer")
			properties.checkoutPreference.addExcludedPaymentType("ticket")
		}
		return properties.checkoutPreference.getExcludedPaymentTypesIds()
	}
	
	func getDefaultPaymentMethodId() -> String? {
		return properties.checkoutPreference.getDefaultPaymentMethodId()
	}
	
	func getExcludedPaymentMethodsIds() -> [String] {
		return properties.checkoutPreference.getExcludedPaymentMethodsIds()
	}
	
	func updateInitModel(paymentMethodsResponse: PXInitDTO?) {
		properties.paymentMethodSearchResult = paymentMethodsResponse
	}
	
	func getPaymentMethodSearch() -> PXInitDTO? {
		return properties.paymentMethodSearchResult
	}
	
	func populateCheckoutStore() {
		PXCheckoutStore.sharedInstance.paymentDatas = [self.properties.paymentData]
		if let splitAccountMoney = amountHelper.splitAccountMoney {
			PXCheckoutStore.sharedInstance.paymentDatas.append(splitAccountMoney)
		}
		PXCheckoutStore.sharedInstance.checkoutPreference = self.properties.checkoutPreference
	}
}

// MARK: nextStep - State machine
extension InitFlowModel {
	func nextStep() -> Steps {
		if let retryStep = pendingRetryStep {
			pendingRetryStep = nil
			return retryStep
		}
		if hasError() {
			return .ERROR
		}
		if needSearch() {
			return .SERVICE_GET_INIT
		}
		return .FINISH
	}
}

// MARK: Needs methods
extension InitFlowModel {
	
	// Use this method for init property.
	func needSkipRyC() -> Bool {
		if let paymentProc = properties.paymentPlugin, let shouldSkip = paymentProc.shouldSkipUserConfirmation, shouldSkip() {
			return true
		}
		return false
	}
	
	private func needSearch() -> Bool {
		return properties.paymentMethodSearchResult == nil
	}
	
	private func hasError() -> Bool {
		return flowError != nil
	}
	
	private func filterCampaignsByCodeType(campaigns: [PXCampaign]?, _ codeType: String) -> [PXCampaign]? {
		if let campaigns = campaigns {
			let filteredCampaigns = campaigns.filter { (campaign: PXCampaign) -> Bool in
				return campaign.codeType == codeType
			}
			if filteredCampaigns.isEmpty {
				return nil
			}
			return filteredCampaigns
		}
		return nil
	}
}
