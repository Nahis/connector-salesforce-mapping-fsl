trigger DispatchServiceProvider on ServiceTerritory (after insert,after update) {

	// ---------------------------------------------------------------------------
	// Dispatch
	// ---------------------------------------------------------------------------
	if (Trigger.isAfter) {
		if (DispatchTriggerHandler.triggersEnabled()) {
			DispatchTriggerHandler.disableTriggers();
			DispatchTriggerHandler.ServiceProviderToDispatch(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);
			DispatchTriggerHandler.enableTriggers();
		}
	}
	// ---------------------------------------------------------------------------	

}