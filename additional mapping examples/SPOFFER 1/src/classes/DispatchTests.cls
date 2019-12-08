@isTest
private class DispatchTests
{
    
    private static DataFactory df = new DataFactory();

      public static void createProductionSettings(String dispatchMethod) {
        Map<String,String> newSettings = new Map<String,String>();
        newSettings.put('DISPATCH_API_PROD_OR_SANDBOX','PRODUCTION');
        newSettings.put('DISPATCH_API_CLIENT_SECRET', 'asdf');
        newSettings.put('DISPATCH_API_CLIENT_ID', 'dsaf');
        newSettings.put('DISPATCH_API_PASSWORD','asfed');
        newSettings.put('DISPATCH_API_WEBHOOK_DEBUG','ON');
        newSettings.put('INTEGRATION_USER_DOMAIN','example.com');
        newSettings.put('DISPATCH_ASSIGN_METHOD', dispatchMethod);
        newSettings.put('LOGGING_KEY', 'xxx');
                
        system.assertNotEquals(newSettings, null);
        Map<String, dispconn__Dispatch_CS__c> settings = dispconn__Dispatch_CS__c.getall();
        List<dispconn__Dispatch_CS__c> updates = new List<dispconn__Dispatch_CS__c>();
        for (String key : newSettings.keySet()) {
            dispconn__Dispatch_CS__c setting = new dispconn__Dispatch_CS__c(Name=key);
            if (settings.containsKey(key)) {
              setting = settings.get(key);
            }
          setting.dispconn__Value__c = newSettings.get(key);
          updates.add(setting);
        }
        upsert updates;

      } 

    public static Account createAccount() {
        Account a = new Account(FirstName='John',
                                LastName='Davis',
                                PersonEmail = 'customer@abc.com',
                                BillingStreet='1 Beacon St',
                                BillingState='Massachusetts',
                                BillingCity='Boston',
                                BillingPostalCode='03312');
        a.RecordTypeId = [SELECT Id FROM RecordType WHERE DeveloperName = 'PersonAccount'].Id;
        system.assertNotEquals(a, null);
        return a;       
    }
    
    public static Contract createContract(String accountId) {
        Contract a = new Contract(Name='John Davis',
                                    Email_with_Multiple_Address__c = 'customer@abc.com',
                                    Primary_Phone__c='5552321244',
                                    AccountId = accountId,
                                    BillingStreet='1 Beacon St',
                                    BillingState='Massachusetts',
                                    BillingCity='Boston',
                                    BillingPostalCode='03312'
        );
        system.assertNotEquals(a, null);
        return a;       
    }

    public static Account createServiceProvider(String name, String phone, String email, String street, Boolean DispatchMe) {
        String rtId = [select Id from RecordType where SObjectType = 'Account' and DeveloperName = 'Contractor_Account'][0].Id;
        Account a = new Account(name=name,
                                RecordTypeId=rtId,
                                Dispatch_me__c = DispatchMe,
                                Business_Email__c = email,
                                Phone = phone,
                                ShippingStreet = street,
                                ShippingState='Massachusetts',
                                ShippingCity='Boston',
                                ShippingPostalCode='03312',
                                First_Hour_Labor_Rate__c=100);
        system.assertNotEquals(a, null);
        return a;

    }

    public static Case createCase(String customerId, String policyId, String policyNumber) {
        Case c = new Case(
                         ContactId=customerId,
                         Subject='subject',
                         Description='description',
                         Type='Claim Submission',
                         //Policy_Number__c=policyNumber,
                         Policy__c=policyId,
                         Claim_Approved_Amount__c=1000,
                         Contractor_Authorized_Amount__c=1100,
                         Customer_Authorized_Amount__c=1200,
                         Invoice_Due_Date__c=Date.today(),
                         Issue_Detail__c = 'Bronze',
                         Reason = 'Support');
        system.assertNotEquals(c, null);
        return c;
    }

    public static Work_Order__c createWorkOrder(String caseId) {
        Work_Order__c c = new Work_Order__c(
                         Claim__c=caseId,
                         WO_Authorized_Date__c=Date.today(),
                         Description__c = 'WO Description',
                         Not_To_Exceed__c = '180');
        system.assertNotEquals(c, null);
        return c;
    }

    public static Note createNote(String parId,String title) {
      Note a = new Note(Title=title,
                      Body=title,
                      ParentId=parId);
      system.assertNotEquals(a, null);
      system.debug('*** Notes: '+title);
      return a;
    }    
 
    public static Attachment createAttachment(String jobId) {
        Attachment att = new Attachment(ParentId=jobId,
                            Name='test Attachment here',
                            Body=Blob.valueOf('this is a test message here'));
        
        system.assertNotEquals(att, null);
        return att;
    }        

    static void resetTriggerForTest() {
        DispatchTriggerHandler.firstRun = true;  
    }

    @isTest
    static void EndToEnd()
    {
        df.createGlobalSetting();
        
        createProductionSettings('SPOFFER');
        Account serviceProvider = createServiceProvider('Select Contractor', '5552321244', 'customer@abc.com', '1 Beacon St', True);
        insert serviceProvider;
        dispconn__Service_Provider__c dispSP=[select Id, Ext_Service_Provider__c from dispconn__Service_Provider__c WHERE Ext_Service_Provider__c =: serviceProvider.Id];
        system.assertEquals(dispSP.Ext_Service_Provider__c, serviceProvider.Id);

        Account account = createAccount();
        insert account;
        Contact contact = [SELECT Id FROM Contact WHERE AccountId = :account.Id LIMIT 1];
        Contract contract = createContract(account.Id);
        insert contract;

        Case cas = createCase(contact.Id,contract.Id,'P-12344');
        insert cas;

        resetTriggerForTest();
        Work_Order__c extJob = createWorkOrder(cas.Id);
        insert extJob;
        extJob.Contractor__c = serviceProvider.Id;
        update extJob;
        dispconn__Job__c dispJob = [select Id, Ext_Job__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.assertEquals(dispJob.Ext_Job__c, extJob.Id);

        resetTriggerForTest();
        extJob.Status__c = 'Accepted';
        update extJob;
        dispJob = [select Id, dispconn__Status__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.assertEquals('Accepted', dispJob.dispconn__Status__c);

        resetTriggerForTest();
        extJob.Status__c = 'Completed';
        update extJob;
        dispJob = [select Id, dispconn__Status__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.assertEquals('Completed', dispJob.dispconn__Status__c);

        resetTriggerForTest();
        extJob.Status__c = 'Canceled';
        update extJob;
        dispJob = [select Id, dispconn__Status__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.assertEquals('Canceled', dispJob.dispconn__Status__c);

        resetTriggerForTest();
        dispJob.dispconn__Status__c = 'Accepted';
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Accepted', extJob.Status__c);

        resetTriggerForTest();
        dispJob.dispconn__Status__c = 'Rejected';
        dispJob.dispconn__Status_Message__c = 'No Availability';
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Rejected: No Availability', extJob.Status__c);

        resetTriggerForTest();
        dispJob.dispconn__Status__c = 'Paused'; 
        dispJob.dispconn__Status_Message__c = 'Stam';
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Paused: Stam', extJob.Status__c);

        resetTriggerForTest();
        dispJob.dispconn__Status_Message__c = 'Wrong trade';
        dispJob.dispconn__Status__c = 'Rejected'; 
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Rejected: Wrong trade', extJob.Status__c);        

        resetTriggerForTest();
        dispJob.dispconn__Status__c = 'Completed'; 
        dispJob.dispconn__Status_Message__c = 'Stam';
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Completed: Stam', extJob.Status__c);        

        resetTriggerForTest();
        dispJob.dispconn__Status_Message__c = 'Billing issue';
        dispJob.dispconn__Status__c = 'Rejected'; 
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        //system.assertEquals('Rejected: Billing issue', extJob.Status__c);

        resetTriggerForTest();
        dispJob.dispconn__Status__c = 'Scheduled'; 
        dispJob.dispconn__Scheduled_Date__c = DateTime.now();
        dispJob.dispconn__Estimated_Duration__c = 2;
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Scheduled', extJob.Status__c);        

        resetTriggerForTest();
        dispJob.dispconn__Status__c = 'Rescheduled'; 
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Rescheduled', extJob.Status__c);

        resetTriggerForTest();
        dispJob.dispconn__Status_Message__c = 'Incorrect service area';
        dispJob.dispconn__Status__c = 'Rejected';
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Rejected: Incorrect service area', extJob.Status__c);        

        resetTriggerForTest();
        dispJob.dispconn__Status__c = 'Enroute'; 
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Enroute', extJob.Status__c);

        resetTriggerForTest();
        dispJob.dispconn__Status__c = 'Started'; 
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Started', extJob.Status__c);

        resetTriggerForTest();
        dispJob.dispconn__Status__c = 'Canceled'; 
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Canceled', extJob.Status__c);          

        resetTriggerForTest();
        dispJob.dispconn__Rating__c = 5; 
        dispJob.dispconn__Rating_Message__c = '!!';
        update dispJob;
        extJob = [select Id, Rating__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals(5, extJob.Rating__c);     

        resetTriggerForTest();
        /*String recType = [select Id from RecordType where Name = 'Appliance' and SobjectType = 'Authorization_Form__c'].Id;
        dispJob.dispconn__Custom_Form_Data__c = '{"form_name":"autho1","form_data":[{"value":"'+recType+'","name":"auth_type"},{"value":"LG","name":"brand"},{"value":"Hh","name":"model"},{"value":"Excellent","name":"condition"},{"value":"Ghhjj","name":"issue_description"},{"value":"87","name":"labor_rate"},{"value":"false","name":"previous_repairs"},{"value":"false","name":"scf_collect"},{"value":"false","name":"rust_or_corrosion"},{"value":"false","name":"on_site_now"},{"value":"false","name":"job_can_be_done_today"},{"value":"false","name":"unit_been_maintained"},{"value":"false","name":"leaking_freon"},{"value":"false","name":"leaking_water"},{"value":"Hhhg","name":"cause_of_failure"},{"value":"true","name":"send_for_approval"}]}'; 
        update dispJob;
        Authorization_Form__c authForm = [select Id, Brand__c from Authorization_Form__c WHERE Work_Order__c =: extJob.Id];
        system.assertEquals('LG', authForm.Brand__c);

        resetTriggerForTest();
        authForm.Authorization_Status__c = 'Approved'; 
        update authForm;
        dispJob = [select Id, dispconn__Description__c from dispconn__Job__c WHERE Id =: dispJob.Id];
        system.assertEquals('**CLAIM APPROVAL STATUS: APPROVED', dispJob.dispconn__Description__c.left(33));   */       

        resetTriggerForTest();
        Note dispNote = createNote(dispJob.Id,'NOTE ONE');
        insert dispNote;
        //Field_Note__c extNote = [select Id, Name from Field_Note__c WHERE Id =: extJob.Id];
        //system.assertEquals('NOTE ONE', extNote.Name);          

    }

 @isTest
    static void CreateDispatchJobCases()
    {
        df.createGlobalSetting();
        
        createProductionSettings('SPOFFER');
        Account serviceProvider1 = createServiceProvider('Contractor 1', '5552321245', 'contractor1@abc.com', '1 Washington St', True);
        insert serviceProvider1;
        List<dispconn__Service_Provider__c> dispSPs = [select Id, Ext_Service_Provider__c from dispconn__Service_Provider__c WHERE Ext_Service_Provider__c =: serviceProvider1.Id];
        system.assertEquals(dispSPs[0].Ext_Service_Provider__c, serviceProvider1.Id); 

        resetTriggerForTest();
        Account serviceProvider2 = createServiceProvider('Contractor 2', '555232188', 'contractor2@abc.com', '2 Washington St', False);
        insert serviceProvider2;
        dispSPs = [select Id, Ext_Service_Provider__c from dispconn__Service_Provider__c WHERE Ext_Service_Provider__c =: serviceProvider2.Id];
        system.assertEquals(0, dispSPs.size());

        Account account = createAccount();
        insert account;
        Contact contact = [SELECT Id FROM Contact WHERE AccountId = :account.Id LIMIT 1];
        Contract contract = createContract(account.Id);
        insert contract;

        Case cas = createCase(contact.Id,contract.Id,'P-55551');
        insert cas;
        List<Work_Order__c> WOs = [select Id from Work_Order__c WHERE Claim__c =: cas.Id];

        system.debug('Dispatch: create work order under normal conditions ==> Dispatch job created');
        resetTriggerForTest();
        Work_Order__c extJob = createWorkOrder(cas.Id);
        insert extJob;
        extJob.Description__c = 'Updated description';
        List<dispconn__Job__c> dispJobs = [select Id, Ext_Job__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];

        system.debug('Dispatch: not yet created as only description changed');
        system.assertEquals(0, dispJobs.size());
        resetTriggerForTest();
        extJob.Contractor__c = serviceProvider1.Id;
        update extJob;
        dispJobs = [select Id, Ext_Job__c, dispconn__Description__c, dispconn__Status__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.debug('Dispatch: created as contractor added '+ dispJobs[0].dispconn__Description__c);
        system.assertEquals(dispJobs[0].Ext_Job__c, extJob.Id);
        system.assertEquals('New', dispJobs[0].dispconn__Status__c);
        system.assert(dispJobs[0].dispconn__Description__c.contains('Not To Exceed: $180'));

        resetTriggerForTest();
        cas.Description = 'Updated description case 1234';
        update cas;
        extJob.Description__c = 'Updated description work order 1234';
        update extJob;
        dispJobs = [select Id, Ext_Job__c, dispconn__Description__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.debug('Dispatch: change description and ensure it is reflected');
        system.assert(dispJobs[0].dispconn__Description__c.contains(cas.Description));  // the update is taken from the claim not work order

        system.debug('Dispatch: create work where contractor is not dispatch enabled ==> Dispatch job not created');
        resetTriggerForTest();
        extJob = createWorkOrder(cas.Id);
        insert extJob;
        extJob.Contractor__c = serviceProvider2.Id;
        update extJob;
        dispJobs = [select Id, Ext_Job__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.assertEquals(0, dispJobs.size());

        system.debug('Dispatch: Now Enable DispatchMe flag ==> Dispatch Service Provider created');
        resetTriggerForTest();
        serviceProvider2.Dispatch_Me__c = True;
        update serviceProvider2;
        dispSPs=[select Id, Ext_Service_Provider__c from dispconn__Service_Provider__c WHERE Ext_Service_Provider__c =: serviceProvider2.Id];
        system.assertEquals(dispSPs[0].Ext_Service_Provider__c, serviceProvider2.Id); 

        system.debug('Dispatch: create work order after contractor is dispatch enabled ==> Dispatch job created');
        resetTriggerForTest();
        extJob = createWorkOrder(cas.Id);
        insert extJob;
        extJob.Contractor__c = serviceProvider2.Id;
        update extJob;
        dispJobs = [select Id, Ext_Job__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.assertEquals(extJob.Id, dispJobs[0].Ext_Job__c);

        system.debug('Dispatch: Disable DispatchMe flag (again)');
        resetTriggerForTest();
        serviceProvider2.Dispatch_Me__c = False;
        update serviceProvider2;

        system.debug('Dispatch: create work order after contractor is dispatch disabled again ==> Dispatch job not created');
        resetTriggerForTest();
        extJob = createWorkOrder(cas.Id);
        insert extJob;
        extJob.Contractor__c = serviceProvider2.Id;
        update extJob;
        dispJobs = [select Id, Ext_Job__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.assertEquals(0, dispJobs.size());

        system.debug('Dispatch: Re-enable DispatchMe flag (again)');
        serviceProvider2.Dispatch_Me__c = True;
        update serviceProvider2;
        system.debug('Dispatch: Test old work order not sent to Dispatch until Contractor changed ');
        // resetTriggerForTest(); DO NOT RESET TRIGGER SO THIS IS NOT YET SENT TO DISPATCH
        extJob = createWorkOrder(cas.Id);
        insert extJob;
        extJob.Contractor__c = serviceProvider2.Id;
        update extJob;
        dispJobs = [select Id, Ext_Job__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.debug('Dispatch: Confirm this is not yet sent to Dispatch');
        system.assertEquals(0, dispJobs.size());

        system.debug('Dispatch: Now change the description ==> should not yet be sent as contractor not changed');
        resetTriggerForTest();
        extJob.Description__c = 'Updated Description 3';
        update extJob;
        dispJobs = [select Id, Ext_Job__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.assertEquals(0, dispJobs.size());

        system.debug('Dispatch: Set the contractor to the same value ==> should not yet be sent as contractor not changed');
        resetTriggerForTest();
        extJob.Contractor__c = serviceProvider2.Id;
        update extJob;
        dispJobs = [select Id, Ext_Job__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.assertEquals(0, dispJobs.size());

        system.debug('Dispatch: Set the contractor to different value ==> should be sent as contractor changed');
        resetTriggerForTest();
        extJob.Contractor__c = serviceProvider1.Id;
        update extJob;
        dispJobs = [select Id, Ext_Job__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.assertEquals(extJob.Id, dispJobs[0].Ext_Job__c);

        system.debug('Dispatch: Test Completion');
        resetTriggerForTest();
        extJob.Auth_Approval_Status__c = 'Check Mailed';
        update extJob;
        dispJobs = [select Id, Ext_Job__c, dispconn__Status__c from dispconn__Job__c WHERE Ext_Job__c =: extJob.Id];
        system.assertEquals('Completed', dispJobs[0].dispconn__Status__c);
    }        


    @isTest
    static void orgRetryDispatchBatch()  {

        resetTriggerForTest();
        Test.startTest();
        // set up
        Account serviceProvider = createServiceProvider('Select Contractor', '5552321244', 'customer@abc.com', '1 Beacon St', True);
        insert serviceProvider;
        
        List<dispconn__Service_Provider__c> lstRecordsToUpdate = new List<dispconn__Service_Provider__c>();
        for (dispconn__Service_Provider__c j: [SELECT id FROM dispconn__Service_Provider__c]) {
          j.dispconn__Last_Sync_Response_Code__c = '422';
          lstRecordsToUpdate.add(j); 
        }
        if(lstRecordsToUpdate.size() > 0) { 
            update lstRecordsToUpdate; 
        }
        DispatchOrgRetry_batch retryJobs = new DispatchOrgRetry_batch();
        Id retryBatchId = Database.executeBatch(retryJobs);        
        Test.stopTest();
        system.debug('*** orgRetryDispatchBatch Assertion 2');
    }    

    @isTest
    static void testSchedule() {
        Test.StartTest();
        DispatchOrgRetry_schedule sh1 = new DispatchOrgRetry_schedule();
        String sch = '0 0 23 * * ?'; system.schedule('Test Schedule Check', sch, sh1); Test.stopTest(); 
    }        


}