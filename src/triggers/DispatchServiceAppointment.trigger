trigger DispatchServiceAppointment on ServiceAppointment (after update) {

	// ---------------------------------------------------------------------------
	// Dispatch
	// ---------------------------------------------------------------------------
	// trigger is only after pdate in this case because we send to dispatch only after the job is assigned which can only happen after it's been created.
	// If you want to send the job earlier then you can add after insert
	if (Trigger.isUpdate && Trigger.isAfter) {
		if (DispatchTriggerHandler.triggersEnabled()) {
			DispatchTriggerHandler.disableTriggers();
			DispatchTriggerHandler.DispatchJobToDispatch(Trigger.new, Trigger.old, Trigger.newMap, Trigger.oldMap);

			DispatchTriggerHandler.enableTriggers();
		}
	}
	// ---------------------------------------------------------------------------


}