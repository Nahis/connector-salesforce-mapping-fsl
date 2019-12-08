// Run this script to schedule a job retry script to run every 10 mins

for(CronTrigger ct : [SELECT Id, CronJobDetail.Name, CronJobDetail.JobType FROM CronTrigger WHERE CronJobDetail.Name like 'Dispatch Reprocess%']) {
  try{
    system.debug(LoggingLevel.ERROR,'Deleting Job: '+ ct.CronJobDetail.Name);
    system.abortJob(ct.id);
  } catch (exception e) {}
}

dispconn.DispatchJob_RetrySchedule reprocess1 = new dispconn.DispatchJob_RetrySchedule();
System.Schedule('Dispatch Reprocess-2', '0 2 * * * ? ', reprocess1);

dispconn.DispatchJob_RetrySchedule reprocess2 = new dispconn.DispatchJob_RetrySchedule();
System.Schedule('Dispatch Reprocess-12', '0 12 * * * ? ', reprocess2);

dispconn.DispatchJob_RetrySchedule reprocess3 = new dispconn.DispatchJob_RetrySchedule();
System.Schedule('Dispatch Reprocess-22', '0 22 * * * ? ', reprocess3);

dispconn.DispatchJob_RetrySchedule reprocess4 = new dispconn.DispatchJob_RetrySchedule();
System.Schedule('Dispatch Reprocess-32', '0 32 * * * ? ', reprocess4);

dispconn.DispatchJob_RetrySchedule reprocess5 = new dispconn.DispatchJob_RetrySchedule();
System.Schedule('Dispatch Reprocess-42', '0 42 * * * ? ', reprocess5);

dispconn.DispatchJob_RetrySchedule reprocess6 = new dispconn.DispatchJob_RetrySchedule();
System.Schedule('Dispatch Reprocess-52', '0 52 * * * ? ', reprocess6);  


// To intitiate manual run
dispconn.DispatchJob_Retry jobBatch = new dispconn.DispatchJob_Retry();
ID batchId = Database.executeBatch(jobBatch,10);