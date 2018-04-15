trigger DispatchServiceTerritory on ServiceTerritory (after insert,after update) {
	// ---------------------------------------------------------------------------
	// Dispatch
	// ---------------------------------------------------------------------------
    // *** FSL: This trigger is configured to fire after insert and update. Verify that this should be the case in your instance too.
	if (Trigger.isAfter) {
		if (DispatchTriggerHandler.triggersEnabled()) {
			DispatchTriggerHandler.disableTriggers();
			DispatchTriggerHandler.ServiceProviderToDispatch(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);
			DispatchTriggerHandler.enableTriggers();
		}
	}
	// ---------------------------------------------------------------------------	
}