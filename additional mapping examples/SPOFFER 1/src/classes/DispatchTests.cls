@isTest
private class DispatchTests
{
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

    public static Contact createCustomer() {
    	Contact a = new Contact(FirstName='John',
    		                    LastName='Davis',
    		                    Email = 'customer@abc.com',
    		                    MobilePhone='5552321244',
                                MailingStreet='1 Beacon St',
                                MailingState='Massachusetts',
                                MailingCity='Boston',
                                MailingPostalCode='03312');
    	system.assertNotEquals(a, null);
    	return a;    	
    }

 	public static Account createServiceProvider() {
    	String rtId = [select Id from RecordType where SObjectType = 'Account' and DeveloperName = 'Contractor_Account'][0].Id;
    	Account a = new Account(name='Select Contractor',
    		                    RecordTypeId=rtId,
    		                    Dispatch_me__c = True,
    		                    Business_Email__c = 'customer@abc.com',
    		                    Phone='5552321244',
                                BillingStreet='1 Beacon St',
                                BillingState='Massachusetts',
                                BillingCity='Boston',
                                BillingPostalCode='03312',
                                First_Hour_Labor_Rate__c=100);
    	system.assertNotEquals(a, null);
    	return a;

    }

    public static Case createCase(String customerId) {
    	Case c = new Case(
    		             ContactId=customerId,
    		             Subject='subject',
    		             Description='description',
    		             Type='Claim Submission',
    		             Policy_Number__c='P-12344',
    		             Claim_Approved_Amount__c=1000,
    		             Contractor_Authorized_Amount__c=1100,
    		             Customer_Authorized_Amount__c=1200,
                         Invoice_Due_Date__c=Date.today(),
                         Issue_Detail__c = 'Bronze',
                         Reason = 'Support');
    	system.assertNotEquals(c, null);
    	return c;
    }

    public static Work_Order__c createWorkOrder(String serviceProviderId, String caseId) {
    	Work_Order__c c = new Work_Order__c(
    		             Claim__c=caseId,
    		             Contractor__c=serviceProviderId,
    		             WO_Authorized_Date__c=Date.today(),
    		             Description__c = 'WO Description');
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
	static void itShould()
	{
        
        createProductionSettings('SPOFFER');
        Account serviceProvider = createServiceProvider();
		insert serviceProvider;
        dispconn__Service_Provider__c dispSP=[select Id, Ext_Service_Provider__c from dispconn__Service_Provider__c WHERE Ext_Service_Provider__c =: serviceProvider.Id];
        system.assertEquals(dispSP.Ext_Service_Provider__c, serviceProvider.Id);

        Contact customer = createCustomer();
		insert customer;

		Case cas = createCase(customer.Id);
		insert cas;

		resetTriggerForTest();
		Work_Order__c extJob = createWorkOrder(serviceProvider.Id,cas.Id);
		insert extJob;
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
        system.assertEquals('Rejected: No availability', extJob.Status__c);

        resetTriggerForTest();
        dispJob.dispconn__Status__c = 'Paused'; 
        dispJob.dispconn__Status_Message__c = 'Stam';
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Paused', extJob.Status__c);

        resetTriggerForTest();
        dispJob.dispconn__Status_Message__c = 'Wrong Trade';
        dispJob.dispconn__Status__c = 'Rejected'; 
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Rejected: Wrong trade', extJob.Status__c);        

        resetTriggerForTest();
        dispJob.dispconn__Status__c = 'Completed'; 
        dispJob.dispconn__Status_Message__c = 'Stam';
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Completed', extJob.Status__c);        

        resetTriggerForTest();
        dispJob.dispconn__Status_Message__c = 'billing issue';
        dispJob.dispconn__Status__c = 'Rejected'; 
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Rejected: Billing issue', extJob.Status__c);

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
        dispJob.dispconn__Status_Message__c = 'INcorrect service area';
        dispJob.dispconn__Status__c = 'Rejected';
        update dispJob;
        extJob = [select Id, Status__c from Work_Order__c WHERE Id =: extJob.Id];
        system.assertEquals('Rejected: Incorrect service area', extJob.Status__c);        

        /* TODO: uncomment when picklist unrestricted
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
        */        

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
        dispJob.dispconn__Custom_Form_Data__c = '{"form_name":"autho1","form_data":[{"value":"0121D0000005AghQAE","name":"auth_type"},{"value":"LG","name":"brand"},{"value":"Hh","name":"model"},{"value":"Excellent","name":"condition"},{"value":"Ghhjj","name":"issue_description"},{"value":"87","name":"labor_rate"},{"value":"false","name":"previous_repairs"},{"value":"false","name":"scf_collect"},{"value":"false","name":"rust_or_corrosion"},{"value":"false","name":"on_site_now"},{"value":"false","name":"job_can_be_done_today"},{"value":"false","name":"unit_been_maintained"},{"value":"false","name":"leaking_freon"},{"value":"false","name":"leaking_water"},{"value":"Hhhg","name":"cause_of_failure"},{"value":"true","name":"send_for_approval"}]}'; 
        update dispJob;
        Authorization_Form__c authForm = [select Id, Brand__c from Authorization_Form__c WHERE Work_Order__c =: extJob.Id];
        system.assertEquals('LG', authForm.Brand__c);

        resetTriggerForTest();
        authForm.Authorization_Status__c = 'Approved'; 
        update authForm;
        dispJob = [select Id, dispconn__Description__c from dispconn__Job__c WHERE Id =: dispJob.Id];
        system.assertEquals('**CLAIM APPROVAL STATUS: APPROVED', dispJob.dispconn__Description__c.left(33));          

        resetTriggerForTest();
        Note dispNote = createNote(dispJob.Id,'NOTE ONE');
        insert dispNote;
        //Field_Note__c extNote = [select Id, Name from Field_Note__c WHERE Id =: extJob.Id];
        //system.assertEquals('NOTE ONE', extNote.Name);          

	}

}