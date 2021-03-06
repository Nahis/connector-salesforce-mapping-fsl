trigger DispatchServiceAppointment on ServiceAppointment (after update) {

	// ---------------------------------------------------------------------------
	// Dispatch
	// ---------------------------------------------------------------------------
    // *** FSL: This trigger is configured to fire after update because we send to dispatch only after the job is assigned 
	//          which can only happen after it's been created. If you want to send the job earlier then you can add after insert
	if (Trigger.isUpdate && Trigger.isAfter) {
		if (DispatchTriggerHandler.triggersEnabled()) {
			DispatchTriggerHandler.disableTriggers();
			DispatchTriggerHandler.JobToDispatch(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);

			DispatchTriggerHandler.enableTriggers();
		}
	}
	// ---------------------------------------------------------------------------
}