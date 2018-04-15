trigger DispatchNote on Note (after insert) {
	// ---------------------------------------------------------------------------
	// Dispatch
    // *** FSL: Normally the same trigger can be used to send updates in both directions but as FSL 
	// ***      does not have notes on the Service Appointment this will only go from Dispatch 
	// ---------------------------------------------------------------------------
	if (Trigger.isInsert && Trigger.isAfter) {
		if (DispatchTriggerHandler.triggersEnabled()) {
			DispatchTriggerHandler.disableTriggers();
			DispatchTriggerHandler.NoteFromToDispatch(Trigger.new);
			DispatchTriggerHandler.enableTriggers();
		}
	}
	// ---------------------------------------------------------------------------	
}