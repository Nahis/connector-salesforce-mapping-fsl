@isTest
private class DispatchTests
/* These test classes are not complete. At the moment they only provide about 63% coverage. They are provided as a sample - you will need to update
   these test classes to suit your implementation.
 */

{

  static void resetTriggerForTest() {
    DispatchTriggerHandler.firstRun = true;  
  }

	public static OperatingHours createOperatingHours() {
		return new OperatingHours(Name='24x7', timezone='America/Los_Angeles');
  }

  public static ServiceTerritory createServiceProvider(String name, Boolean dispMe,OperatingHours oh) {
	    return new ServiceTerritory(Name=name, OperatingHoursId=oh.Id, IsActive=true, Dispatch_me__c=dispMe,
	    	                      Email__c = name+'@abc.com', Phone__c='5552321244');
  }

  public static User createUser() {
      Profile p = [SELECT Id FROM Profile WHERE Name='Standard User']; 
      return new User(Alias='nahi', Email='nahi+fsl@dispatch.me', 
          EmailEncodingKey='UTF-8', LastName='Simon', LanguageLocaleKey='en_US', 
          LocaleSidKey='en_US', ProfileId = p.Id, 
          TimeZoneSidKey='America/Los_Angeles', UserName='nahi+fsl@dispatch.me');
  }

  public static void assignPermission(User user) {
     PermissionSet ps = [SELECT ID From PermissionSet WHERE Name = 'Field Service Standard'];
     insert new PermissionSetAssignment(AssigneeId = user.id, PermissionSetId = ps.Id );
  }

  public static ServiceResource createResource(User user,Boolean dispMe,Boolean portalAccess) {
      return new ServiceResource(Name='Nahi Simon',RelatedRecordId=user.Id,ResourceType='T',IsActive=True,Dispatch_me__c=dispMe,Dispatch_Portal_Access__c=portalAccess);
  }  

  public static Contact createContact(Boolean withAddress) {
    Contact c = new Contact();
      c.firstname='Test';
      c.lastname='Customer';
      if (withAddress) {
          c.mailingstreet='123 My St.\nSuite 2';
          c.mailingcity='Boston';
          c.mailingstate='MA';
          c.mailingpostalcode='02020';
          c.mailingcountry='United States';
      }    
      c.email='test@example.com';
      c.phone='617-555-1212';
      c.mobilephone='617-223-2333';
                    
    return c;
  }  

  public static Account createAccount() {
    Account a = new Account(name='Customer');
    return a;
  }  

  public static ServiceAppointment createServiceAppointment(Contact contact,Account account) {
      return new ServiceAppointment(ContactId=contact.Id, Status='None',Subject='Fix Sink',DurationType='Hours',Duration=4,
                                    EarliestStartTime=DateTime.now(),DueDate=DateTime.now(),ParentRecordId=account.Id);
  }  

  public static Note createNote(String parId,String title) {
      return new Note(Title=title,Body=title,ParentId=parId);
  }    

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


  @isTest(SeeAllData=true)
  static void itShould()
  {
    createProductionSettings('SPOFFER');
    
    system.debug('*** Setup: Operating Hours ***');
    OperatingHours oh = createOperatingHours();
    insert oh;

    system.debug('*** ServiceTerritories Tests 1 ***');
    resetTriggerForTest();        
    ServiceTerritory serviceProviderNotInDispatch = createServiceProvider('T1',false,oh);
    insert serviceProviderNotInDispatch;
    List<dispconn__Service_Provider__c> dispSP1=[select Id,Ext_Service_Provider__c from dispconn__Service_Provider__c WHERE Ext_Service_Provider__c =: serviceProviderNotInDispatch.Id];
    system.assertEquals(0,dispSP1.size());  

    system.debug('*** ServiceTerritories Tests 2 ***');
    resetTriggerForTest();        
    ServiceTerritory serviceProviderInDispatch = createServiceProvider('T2',true,oh);
    insert serviceProviderInDispatch;
    List<dispconn__Service_Provider__c> dispSP2=[select Id,Ext_Service_Provider__c from dispconn__Service_Provider__c WHERE Ext_Service_Provider__c =: serviceProviderInDispatch.Id];
    system.assertEquals(1,dispSP2.size());  
    system.assertEquals(serviceProviderInDispatch.Id,dispSP2[0].Ext_Service_Provider__c);  

    /* 
    system.debug('*** Setup: User ***');
    User user1 = createUser();
    insert user1;
    assignPermission(user1);

    system.debug('*** ServiceResource Tests 1 ***');
    resetTriggerForTest();        
    ServiceResource resourceNotInDispatch = createResource(user1,false,false);
    insert resourceNotInDispatch;
    List<dispconn__Field_Tech__c> dispTech1=[select Id,Ext_Tech__c from dispconn__Field_Tech__c WHERE Ext_Tech__c =: resourceNotInDispatch.Id];
    system.assertEquals(1,dispTech1.size());  
    system.assertEquals(resourceNotInDispatch.Id,dispTech1[0].Ext_Tech__c);  
    */

    system.debug('*** Setup: Contact ***');
    Contact contact = createContact(true);
    insert contact;

    system.debug('*** Setup: Account ***');
    Account account = createAccount();
    insert account;    

    system.debug('*** ServiceAppointment Tests 1 ***');
    resetTriggerForTest();        
    ServiceAppointment sa1 = createServiceAppointment(contact,account);
    insert sa1;
    sa1.ServiceTerritoryId = serviceProviderInDispatch.Id;
    update sa1;
    List<dispconn__Job__c> dispJob1=[select Id,Ext_Job__c from dispconn__Job__c WHERE Ext_Job__c =: sa1.Id];    
    system.assertEquals(1,dispJob1.size());  
    system.assertEquals(sa1.Id,dispJob1[0].Ext_Job__c);  


    system.debug('\n\n*** Dispatch: status updates from dispatch ***');
    resetTriggerForTest();
    dispconn__Job__c job = [select Id,Ext_Job__c from dispconn__Job__c][0];
    job.dispconn__Status__c = 'Accepted';
    update job;
    System.assert([select Third_Party_Accepted__c from ServiceAppointment where Id = :job.Ext_Job__c].Third_Party_Accepted__c != null);         

    resetTriggerForTest();
    job.dispconn__Status__c = 'Scheduled';
    job.dispconn__Scheduled_Date__c = DateTime.now();
    job.dispconn__Estimated_Duration__c = 4;
    update job;
    System.assertEquals('Scheduled', [select Status from ServiceAppointment where Id = :job.Ext_Job__c].Status);   

    resetTriggerForTest();
    job.dispconn__Status__c = 'Enroute';
    update job;
    System.assertEquals('Dispatched', [select Status from ServiceAppointment where Id = :job.Ext_Job__c].Status);   

    resetTriggerForTest();
    job.dispconn__Status__c = 'Started';
    update job;
    System.assertEquals('In Progress', [select Status from ServiceAppointment where Id = :job.Ext_Job__c].Status);  

    resetTriggerForTest();
    job.dispconn__Status__c = 'Completed';
    update job;
    System.assertEquals('Completed', [select Status from ServiceAppointment where Id = :job.Ext_Job__c].Status);  

    resetTriggerForTest();
    job.dispconn__Rating__c  = 5;
    job.dispconn__Rating_Message__c = 'Good job';
    update job;
    System.assertEquals(5, [select Dispatch_Rating__c from ServiceAppointment where Id = :job.Ext_Job__c].Dispatch_Rating__c); 

    system.debug('\n\n*** Dispatch: add note to dispatch job');
    resetTriggerForTest();
    Note nt = createNote(job.Id,'doooo');
    insert nt;
    System.assertEquals('doooo', [select Name from Service_Appointment_Note__c where Service_Appointment__c = :job.Ext_Job__c and Name='doooo'].Name);        


  }
}