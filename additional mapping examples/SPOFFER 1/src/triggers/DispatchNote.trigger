trigger DispatchNote on Note (after insert) {
	// ---------------------------------------------------------------------------
	// Dispatch
	// ---------------------------------------------------------------------------
	if (Trigger.isInsert && Trigger.isAfter) {
		if (DispatchTriggerHandler.triggersEnabled()) {
			DispatchTriggerHandler.disableTriggers();
			DispatchTriggerHandler.DispatchNoteFromToDispatch(Trigger.new);
			DispatchTriggerHandler.enableTriggers();
		}
	}
	// ---------------------------------------------------------------------------		

}