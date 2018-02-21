trigger DispatchWorkOrder on Work_Order__c (after insert,after update) {

	// ---------------------------------------------------------------------------
	// Dispatch
	// ---------------------------------------------------------------------------
	if (Trigger.isAfter) {
		if (DispatchTriggerHandler.triggersEnabled()) {
			DispatchTriggerHandler.disableTriggers();
			DispatchTriggerHandler.DispatchJobToDispatch(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);

			DispatchTriggerHandler.enableTriggers();
		}
	}
	// ---------------------------------------------------------------------------
}