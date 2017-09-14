trigger DispatchJob on dispconn__Job__c (after update) {
	// ---------------------------------------------------------------------------
	// Dispatch 
	// ---------------------------------------------------------------------------
    // *** FSL: This trigger is configured to fire only after update. You will want to change that if jobs can originate in Dispatch.
	if (Trigger.isUpdate && Trigger.isAfter) {
		if (DispatchTriggerHandler.triggersEnabled()) {
			DispatchTriggerHandler.disableTriggers();
			DispatchTriggerHandler.DispatchJobFromDispatch(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);
			DispatchTriggerHandler.enableTriggers();
		}
	}
	// ---------------------------------------------------------------------------
}

