trigger DispatchAuthorizationForm on Authorization_Form__c (after update) {
	// ---------------------------------------------------------------------------
	// Dispatch 
	// ---------------------------------------------------------------------------
	if (Trigger.isUpdate && Trigger.isAfter) {
		if (DispatchTriggerHandler.triggersEnabled()) {
			// DispatchTriggerHandler.disableTriggers(); need this enabled to call work order trigger
			DispatchTriggerHandler.AuthorizationForm(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);
			DispatchTriggerHandler.enableTriggers();
		}
	}
	// ---------------------------------------------------------------------------
}