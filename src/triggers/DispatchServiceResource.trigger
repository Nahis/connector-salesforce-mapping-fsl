trigger DispatchServiceResource on ServiceResource (after insert, after update) {
	// ---------------------------------------------------------------------------
	// Dispatch
	// ---------------------------------------------------------------------------
	// only performed after update as the user needs to be linked via Service Territory Member to the Service Territory which can only happen after the record
	// is inserted. In instances where the location is associated directl on the user record this can be done after insert too
	if (Trigger.isUpdate && Trigger.isAfter) {
		if (DispatchTriggerHandler.triggersEnabled()) {
			DispatchTriggerHandler.disableTriggers();

			DispatchTriggerHandler.DispatchTechToDispatch(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);

			DispatchTriggerHandler.enableTriggers();
		}
	}
	// ---------------------------------------------------------------------------	

}