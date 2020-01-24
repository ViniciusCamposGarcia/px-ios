//
//  HookService.swift
//  MercadoPagoSDK
//
//  Created by Juan sebastian Sanzone on 31/7/18.
//  Copyright © 2018 MercadoPago. All rights reserved.
//

import Foundation

@objc internal enum PXHookStep: Int {
	case BEFORE_PAYMENT_METHOD_CONFIG = 1
	case AFTER_PAYMENT_METHOD_CONFIG
	case BEFORE_PAYMENT
}


/// :nodoc:
extension PXInstructions {
	open func hasSecundaryInformation() -> Bool {
		if instructions.isEmpty {
			return false
		} else {
			return instructions[0].hasSecondaryInformation()
		}
	}
	
	open func hasSubtitle() -> Bool {
		if instructions.isEmpty {
			return false
		} else {
			return instructions[0].hasSubtitle()
		}
	}
	
	internal func getInstruction() -> PXInstruction? {
		if instructions.isEmpty {
			return nil
		} else {
			return instructions[0]
		}
	}
}


@objcMembers
internal class PXHookNavigationHandler: NSObject {
	
	private var checkout: MercadoPagoCheckout?
	private var targetHook: PXHookStep?
	
	public init(withCheckout: MercadoPagoCheckout, targetHook: PXHookStep) {
		self.checkout = withCheckout
		self.targetHook = targetHook
	}
	
	open func next() {
		if let targetHook = targetHook, targetHook == .BEFORE_PAYMENT_METHOD_CONFIG {
			if let paymentOptionSelected = self.checkout?.viewModel.paymentOptionSelected {
				self.checkout?.viewModel.updateCheckoutModelAfterBeforeConfigHook(paymentOptionSelected: paymentOptionSelected)
			}
		}
		checkout?.executeNextStep()
	}
	
	open func back() {
		checkout?.executePreviousStep()
	}
	
	open func showLoading() {
		checkout?.viewModel.pxNavigationHandler.presentLoading()
	}
	
	open func hideLoading() {
		checkout?.viewModel.pxNavigationHandler.dismissLoading()
	}
}


/** :nodoc: */
@objc internal protocol PXHookComponent: NSObjectProtocol {
	func hookForStep() -> PXHookStep
	func render(store: PXCheckoutStore, theme: PXTheme) -> UIView?
	@objc optional func shouldSkipHook(hookStore: PXCheckoutStore) -> Bool
	@objc optional func didReceive(hookStore: PXCheckoutStore)
	@objc optional func navigationHandlerForHook(navigationHandler: PXHookNavigationHandler)
	@objc optional func renderDidFinish()
	@objc optional func titleForNavigationBar() -> String?
	@objc optional func colorForNavigationBar() -> UIColor?
	@objc optional func shouldShowBackArrow() -> Bool
	@objc optional func shouldShowNavigationBar() -> Bool
}

final class HookService {
    private var hooks: [PXHookComponent] = [PXHookComponent]()
    private var hooksToShow: [PXHookComponent] = [PXHookComponent]()
}

extension HookService {
    func addHookToFlow(hook: PXHookComponent) -> Bool {
        let matchedHooksForStep = self.hooksToShow.filter { targetHook in
            targetHook.hookForStep() == hook.hookForStep()
        }
        if matchedHooksForStep.isEmpty {
            self.hooks.append(hook)
            self.hooksToShow.append(hook)
        }
        return matchedHooksForStep.isEmpty
    }

    func getHookForStep(hookStep: PXHookStep) -> PXHookComponent? {
        let matchedHooksForStep = self.hooksToShow.filter { targetHook in
            targetHook.hookForStep() == hookStep
        }
        return matchedHooksForStep.first
    }

    func removeHookFromHooksToShow(hookStep: PXHookStep) {
        let noMatchedHooksForStep = self.hooksToShow.filter { targetHook in
            targetHook.hookForStep() != hookStep
        }
        hooksToShow = noMatchedHooksForStep
    }

    func addHookToHooksToShow(hookStep: PXHookStep) {
        let matchedHooksForStep = self.hooks.filter { targetHook in
            targetHook.hookForStep() == hookStep
        }

        for hook in matchedHooksForStep {
            hooksToShow.append(hook)
        }
    }

    func resetHooksToShow() {
        hooksToShow = hooks
    }

    func removeHooks() {
        hooks = []
        hooksToShow = []
    }
}

@objc internal protocol PXComponentizable {
	func render() -> UIView
	@objc optional func oneTapRender() -> UIView
}

internal protocol PXXibComponentizable {
	func xibName() -> String
	func containerView() -> UIView
	func renderXib() -> UIView
}
