trigger DispatchNote on Note (after insert) {
	// ---------------------------------------------------------------------------
	// Dispatch
	// Normally the same trigger can be used to send updates in both directions but as FSL does not have notes on the Service Appointment this will only go from Dispatch 
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