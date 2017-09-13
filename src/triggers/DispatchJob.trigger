trigger DispatchJob on dispconn__Job__c (after update) {
	// ---------------------------------------------------------------------------
	// Dispatch
	// ---------------------------------------------------------------------------

	if (Trigger.isUpdate && Trigger.isAfter) {
		if (DispatchTriggerHandler.triggersEnabled()) {
			DispatchTriggerHandler.disableTriggers();

			DispatchTriggerHandler.DispatchJobFromDispatch(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);

			DispatchTriggerHandler.enableTriggers();
		}
	}

	// ---------------------------------------------------------------------------
}

