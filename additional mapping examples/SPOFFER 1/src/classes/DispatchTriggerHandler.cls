public class DispatchTriggerHandler {

    public static boolean firstRun = true;
    private static Boolean runTriggers = true;
    /* Method to disable triggers by setting boolean to false */
    public static void disableTriggers() { runTriggers = false; }
    /* Method to enable triggers by setting boolean to true */
    public static void enableTriggers() { runTriggers = true; }
    /* Method that returns the value of boolean to determine if trigger is run or not */
    public static Boolean triggersEnabled() { return runTriggers; }
    public class spException extends Exception {}
    public class techException extends Exception {}
    public class jobException extends Exception {}

    private class CustomFormObject {
        public String form_name;
        public List<FormDataObject> form_data;       
    }    
    private class FormDataObject {
        public String name;
        public String value;
    }        

    public static void DispatchServiceProviderToDispatch(List<Account> newList,List<Account> oldList, Map<Id,Account> newMap, Map<Id,Account> oldMap){
		if (!firstRun) { return; }
        firstRun = false;
        List<Account> newListRelevant = new List<Account>();
        Set<Id> locationIds = new Set<Id>();
        for(Account loc: newList) {
            if (loc.Dispatch_me__c) {
                locationIds.add(loc.Id);
                newListRelevant.add(loc);
            }
        }

        if (newListRelevant.size() > 0 ) {
            List<dispconn__Service_Provider__c> dispSPs = [SELECT Id, Ext_Service_Provider__c 
                                                            FROM dispconn__Service_Provider__c 
                                                            WHERE Ext_Service_Provider__c IN :locationIds];
            map<string, dispconn__Service_Provider__c> mapDispSPs = new map<string, dispconn__Service_Provider__c>();
            for(dispconn__Service_Provider__c sp: dispSPs) {
                mapDispSPs.put(sp.Ext_Service_Provider__c, sp);
            }  

            // Create a list for updating
            List<dispconn__Service_Provider__c> dispSPsUpdate = new List<dispconn__Service_Provider__c>();
            
            for (Account extSP : newListRelevant) {
                
                dispconn__Service_Provider__c dispSP;
                dispSP = mapDispSPs.get(extSP.Id);
                if (dispSP == Null) {
                    // SP not found insert
                    dispSP = new dispconn__Service_Provider__c(); 
                }    
                dispSP.Ext_Service_Provider__c = extSP.Id;                    

                dispSP.Name = extSP.Name; // If the name field is "technical" (e.g. X123) then you can map it from other fields e.g. 'Your Company Name ('+extSP.City__c+')';
                dispSP.dispconn__Phone__c = extSP.Phone;
                dispSP.dispconn__Email__c = extSP.Business_Email__c;
                dispSP.dispconn__Usage__c = 'normal';
                dispSP.dispconn__SF_Org_ID__c = extSP.Contractor_Id__c; 
                // need all 4 address components to have a valid address
                if (String.isBlank(extSP.BillingStreet) || String.isBlank(extSP.BillingCity) || String.isBlank(extSP.BillingState) || String.isBlank(extSP.BillingPostalCode) ) {
                    dispSP.dispconn__Address_Street__c      = null;
                    dispSP.dispconn__Address_City__c        = null;
                    dispSP.dispconn__Address_State__c       = null;
                    dispSP.dispconn__Address_Postal_Code__c = null;
                    dispSP.dispconn__Address_Country__c    = null;
                } else {
                    dispSP.dispconn__Address_Street__c      = extSP.BillingStreet;
                    dispSP.dispconn__Address_City__c        = extSP.BillingCity;
                    dispSP.dispconn__Address_State__c       = extSP.BillingState;
                    dispSP.dispconn__Address_Postal_Code__c = extSP.BillingPostalCode;
                    dispSP.dispconn__Address_Country__c = 'United States';
                    if (extSP.BillingCountry == 'CA' || extSP.BillingCountry == 'Canada' ) {  
                        dispSP.dispconn__Address_Country__c = 'Canada';
                    }    

                }

                // Add Service Provider to the list
                dispSPsUpdate.add(dispSP);
            }
            // If there are Service Provider records, then apply updates
            if(dispSPsUpdate.size() > 0) {
                upsert dispSPsUpdate;
            }
        }      	
    }


    public static void DispatchJobToDispatch(List<Work_Order__c> newList,List<Work_Order__c> oldList, Map<Id,Work_Order__c> newMap, Map<Id,Work_Order__c> oldMap){
        if (!firstRun) { return; }
        firstRun = false;

        Set<Id> jobIds = new Set<Id>();    
        Set<Id> caseIds = new Set<Id>();    
        Set<Id> contactIds = new Set<Id>();    
        Set<Id> locationIds = new Set<Id>();    
        List<Work_Order__c> newListRelevant = new List<Work_Order__c>();
        for(Work_Order__c wo: newList) {
            jobIds.add(wo.Id);
            if (wo.Claim__c != null) {
            	caseIds.add(wo.Claim__c);
            }
            if (wo.Contractor__c != null) {
                locationIds.add(wo.Contractor__c);
            }                    
            newListRelevant.add(wo);
        }
        
        if (newListRelevant.size() > 0 ) {
            List<dispconn__Job__c> dispJobs = [SELECT Id, Ext_Job__c, dispconn__Field_Tech__c FROM dispconn__Job__c WHERE Ext_Job__c IN :jobIds];
            map<string, dispconn__Job__c> mapDispJobs = new map<string, dispconn__Job__c>();
            for(dispconn__Job__c j: dispJobs) {
                mapDispJobs.put(j.Ext_Job__c, j);
            }

            List<dispconn__Service_Provider__c> dispSPs = [SELECT Id, Ext_Service_Provider__c, Ext_Service_Provider__r.First_Hour_Labor_Rate__c
                                                           FROM dispconn__Service_Provider__c 
                                                           WHERE Ext_Service_Provider__c IN :locationIds];
            map<string, dispconn__Service_Provider__c> mapDispSPs = new map<string, dispconn__Service_Provider__c>();
            for(dispconn__Service_Provider__c sp: dispSPs) {
                mapDispSPs.put(sp.Ext_Service_Provider__c, sp);
            }

            // FSL: Gather Contact Info for job. If the Service Appointment does not contain the address, the address from the contact record will be used
            List<Case> cases = [SELECT Contact.FirstName, Contact.LastName, Contact.MobilePhone, Contact.Email,
                                             Contact.MailingStreet, Contact.MailingCity, Contact.MailingPostalCode, Contact.MailingState, Contact.MailingCountry,
                                             Subject,Description,Status,Type,Policy_Number__c,Claim_Approved_Amount__c,Contractor_Authorized_Amount__c,Customer_Authorized_Amount__c,
                                             Invoice_Due_Date__c
                                       FROM Case WHERE Id IN :caseIds];
            map<Id, Case> mapCases = new map<Id, Case>(cases);

            // Create a list for updating
            List<dispconn__Job__c> dispJobsUpdate = new List<dispconn__Job__c>();

            for (Work_Order__c extJob : newListRelevant) {
                try {
                    // Lookup corresponding Dispatch Job from map - you should not have to change this logic
                    System.debug('Dispatch: ' + extJob.Name);
                    dispconn__Job__c dispJob;
                    dispJob = mapDispJobs.get(extJob.Id);
                    if (dispJob == Null) {
                        // job not found insert
                        dispJob = new dispconn__Job__c();
                        dispJob.dispconn__Status__c = 'New';
                    }
                    dispJob.Ext_Job__c = extJob.Id;
                    // Initialize - sync statuses. Recommend leaving as is.
                    dispJob.dispconn__Last_Sync_Response__c = 'Pending Sync:'+DateTime.now();
                    dispJob.dispconn__Last_Sync_Response_Code__c = Null;
                    dispJob.dispconn__Synced__c = False;
                    
                    dispconn__Service_Provider__c sp;
                    if (extJob.Contractor__c != null) {
                        sp = mapDispSPs.get(extJob.Contractor__c);
                        if (sp == null) {  // not a valid dispatch territory
                            throw new jobException('Dispatch: not a valid dispatch territory 2');
                        }                        
                        dispJob.dispconn__Service_Provider__c = sp.Id;
                    }

                    /* CONTACT INFO */
                    Case cas = mapCases.get(extJob.Claim__c);
                    if (cas == null) {
                        throw new jobException('Case not linked to the job');
                    }
                    if (!String.isBlank(cas.Contact.FirstName)) {
                        dispJob.dispconn__First_Name__c = cas.Contact.FirstName.left(50);
                    }    
                    if (!String.isBlank(cas.Contact.LastName)) {
                        dispJob.dispconn__Last_Name__c = cas.Contact.LastName.left(50);
                    }
                    String mobilePhone = cas.Contact.MobilePhone;
                    if (!String.isBlank(mobilePhone)) {
                        dispJob.dispconn__Mobile__c = mobilePhone.left(14);
                    }
                    if (!String.isBlank(cas.Contact.Email)) {
                        dispJob.dispconn__Email__c = cas.Contact.Email;
                    }

                    dispJob.dispconn__SF_Job_Id__c = extJob.Name; 
                    /* JOB ADDRESS */
                    dispJob.dispconn__Address_Country__c = 'United States';
                    dispJob.dispconn__Address_Street__c      = cas.Contact.MailingStreet;
                    dispJob.dispconn__Address_City__c        = cas.Contact.MailingCity;
                    dispJob.dispconn__Address_State__c       = cas.Contact.MailingState;
                    dispJob.dispconn__Address_Postal_Code__c = cas.Contact.MailingPostalCode;
                    if (cas.Contact.MailingCountry == 'CA' || cas.Contact.MailingCountry == 'Canada') {
                        dispJob.dispconn__Address_Country__c = 'Canada';
                    }    

                    /* JOB TITLE */
                    if (!String.isBlank(cas.Subject)) {
                        dispJob.dispconn__Title__c = cas.Subject;
                    }  

                    /* JOB DESCRIPTION */
                     /* **ENTRY NOTES:**\n\n* Special Entry: ENTER THROUGH SIDE DOOR; ENTER CODE 2008 AND TURN TO THE LEFT TO ENTER; WHEN LEAVING ENTER 2008 AND TURN TO THE RIGHT TO LOCK\n* Home Entry Code: Special Entry\n* Key: 000\n* Driving Directions: T/L ONTO WEST; T/R ONTO YORK; T/L ONTO FAIRMOUNT; BECOMES GOUCHER; BEAR RIGHT ONTO LOCH RAVEN; T/R ONTO LOCH HILL\n\n**ROOM SUMMARY:**\n\n\nRoom | Level | SA | Instructions | Desc \n---- | ----- | :-: | ----- | ----\nMaster Bedroom | Upper |  |  | \n. |  |  |  | \nBedroom | Upper | Y |  | Pink Bedroom, Top of Stairs\n. |  |  |  | \nBedroom | Upper | Y |  | Daughter&#39; s Bedroom\n. |  |  |  | \nLiving Room | Main |  |  | \n. |  |  |  | \nDining Room | Main |  |  | \n. |  |  |  | \nHallway | Upper |  |  | \n. |  |  |  | \nStairs | Main | Y |  | \n. |  |  |  | \nRec Room | Lower |  |  | \n. |  |  |  | \nKitchen | Main |  |  | \n. |  |  |  | \nMaster Bathroom | Upper |  |  | \n. |  |  |  | \nHalf Bath | Lower | Y |  | \n. |  |  |  | \n\n**CUSTOMER NOTES:**\n\n* **Equipment** Mildew remover; Wall glide; High duster\n\n* **Special Descripiton** MM ADVANTAGE 24; PLEASE BE MINDFUL OF PET HAIR UNDERNEATH FURNITURE; STEAMER DOES NOT WORK WELL ON THE FLOORS IN THIS HOME- PLEASE MOP; PLEASE SPOT CHECK WINDOWS FOR NOSE PRINTS\n\n* **Special Instructions** DOG IS BEAR; TRASH GOES TO CANS OUTSIDE;\n\n\n**PRICING:**\n\n* Due: 125.00\n* Payroll: 87.50\n* A/R: 0.00\n* Paying By: Credit Card
                     */

                    System.debug('Dispatch: description');
                    String serviceCharge = (extJob.Service_Charge__c != null ? String.valueOf(extJob.Service_Charge__c) : '');
                    String descr = '';
                    descr += '**CLAIM APPROVAL STATUS: ';
                    if (!String.isBlank(extJob.Auth_Approval_Status__c)) {
                        descr += extJob.Auth_Approval_Status__c.toUpperCase() + '**';
                    } else {
                        descr += 'PENDING**';
                    }
                    
                    descr += '\n\n**DESCRIPTION:**\n';
                    descr += cas.Description;
                    descr += '\n\n**CLAIM DETAILS:**\n';
                    descr += '\n* Service Charge: $' + serviceCharge;
                    descr += '\n* Policy #: ' +(!String.isBlank(cas.Policy_Number__c) ? cas.Policy_Number__c : '');
                    descr += '\n* Claim Approved Amount: ' +(cas.Claim_Approved_Amount__c != null ? String.valueOf(cas.Claim_Approved_Amount__c) : '');
                    descr += '\n* Customer Authorized Amount: ' +(cas.Customer_Authorized_Amount__c != null  ? String.valueOf(cas.Customer_Authorized_Amount__c) : '');
                    descr += '\n* Contractor Authorized Amount: ' +(cas.Contractor_Authorized_Amount__c != null  ? String.valueOf(cas.Contractor_Authorized_Amount__c) : '');
                    descr += '\n* Invoice Due Date: ' +(cas.Invoice_Due_Date__c != null  ? String.valueOf(cas.Invoice_Due_Date__c) : '');

                    descr += '\n\nACME Corp is sending you work orders via Dispatch. In order to give status to Select, and avoid a phone call, simply "Accept" this offer. You will be taken into Dispatch, a portal where you can schedule the work order, from your computer or your phone. If you need help, reach out at support@dispatch.me';
                    descr += '\n\n**DO NOT COMPLETE ANY REPAIRS THAT TOTAL ABOVE $'+serviceCharge+' WITHOUT APPROVAL FROM ACME Corp. IF THE GROSS REPAIR ESTIMATE EXCEEDS $'+serviceCharge+': PLEASE CONTACT US TO RECEIVE AUTHORIZATION TO COMPLETE THE REPAIRS.  YOU CAN SUBMIT YOUR DIAGNOSIS FOR AUTHORIZATION BY DOING THE FOLLOWING:   1. UPLOAD YOUR DIAGNOSIS VIA THE DISPATCH.ME PORTAL. 2.CONTACT THE AUTHORIZATION DEPARTMENT AT 855-267-3532 OPTION 7.  PLEASE HAVE THE WORK ORDER NUMBER AND COMPLETE DIAGNOSIS ON HAND.**';
                    descr += '\n\n**ALL INVOICES MUST BE UPLOADED TO THE DISPATCH.ME PORTAL OR EMAILED TO invoice@selecthomewarranty.com. WE ENCOURAGE ALL CONTRACTORS TO UPLOAD THEIR INVOICES TO THE DISPATCH PORTAL TO ENSURE THEY RECEIVE PAYMENT PROMPTLY.**';
                    descr += '\n\n**ALL PICTURES SHOULD BE UPLOADED TO THE DISPATCH.ME PORTAL OR EMAILED TO claims@selecthomewarranty.com**';
                    descr += '\n\n**Service Providers are responsible to collect the $'+serviceCharge+' service call fee directly from the customer. The customer is aware of this fee.**';
                    descr += '\n\nACME Corp does not cover the aforementioned policy exceptions, and needs to be made aware of these exceptions while the technician is on site so that ACME Corp can explain the contract coverage to the customer, thereby preventing delays in service and possible miscommunications. A ACME Corp Authorization Agent may refer the customer to the onsite technician for all non-covered repairs.';
                    descr += '\n\nDO NOT MAIL OR FAX INVOICES - UPLOAD TO THE PORTAL OR EMAIL';
                    descr += '\n\nTHE CLAIMS AUTHORIZATION DEPT IS AVAILABLE DURING THE FOLLOWING TIMES:';
                    descr += '\n* MONDAY - THURSDAY 9:00 AM - 7PM';
                    descr += '\n* FRIDAY 9:00 AM-6PM';
                    descr += '\n* SATURDAY 11AM- 5PM';
                    descr += '\n* CLOSED ON SUNDAYS';
                    descr += '\n\nALL TIMES ABOVE ARE EASTERN STANDARD TIME';
     

                    dispJob.dispconn__Description__c = descr;

                    /* SERVICE TYPE */
                    if (!String.isBlank(extJob.Issue_Type__c)) {
                            dispJob.dispconn__Service_Type__c = extJob.Issue_Type__c;
                    } 

                    /* CUSTOM FORM */
                    try {
                        /*if (!String.isBlank(dispJob.dispconn__Custom_Form_Data__c) && someCondition) {
                            CustomFormObject customForm = (CustomFormObject)JSON.deserialize(dispJob.dispconn__Custom_Form_Data__c, CustomFormObject.class);
                            map<String, String> mapFormData = getFormDataMap(customForm.form_data);
                            mapFormData.put('brand','xxx');
                            dispJob.dispconn__Custom_Form_Data__c = JSON.serialize(mapFormData);
                        } else {*/
                            if (dispJob.dispconn__Status__c == 'New' && sp.Ext_Service_Provider__r.First_Hour_Labor_Rate__c != null) {
                                dispJob.dispconn__Custom_Form_Data__c = '{"form_name":"autho1","form_data":[{"name":"labor_rate","value":"'+String.valueOf(sp.Ext_Service_Provider__r.First_Hour_Labor_Rate__c)+'"}]}';
                            }
                        //}
                    } catch (Exception e) {}

                    /*if (extJob.SchedStartTime != null) {
                        dispJob.dispconn__Scheduled_Date__c = extJob.SchedStartTime;
                        dispJob.dispconn__Estimated_Duration__c = extJob.Duration;
                    } */

                    // handle status changes
                    if (oldMap == null || extJob.Status__c != oldMap.get(extJob.Id).Status__c) {
                        if (extJob.Status__c == 'Accepted' ) {
                            dispJob.dispconn__Status__c = 'Accepted';
                        } else if (extJob.Status__c == 'Completed') { 
                            dispJob.dispconn__Status__c = 'Completed';
                        } else if (extJob.Status__c == 'Canceled') { 
                            dispJob.dispconn__Status__c = 'Canceled';
                        } 
                    }    

                    dispJobsUpdate.add(dispJob);

                } catch (jobException e) {
                    System.debug('Dispatch: updateJob exception: '+e.getMessage());
                }
            }
            if (!dispJobsUpdate.isEmpty()) {
                upsert dispJobsUpdate;
            }
        }
    }    

    public static void DispatchJobFromDispatch(List<dispconn__Job__c> newList,List<dispconn__Job__c> oldList, Map<Id,dispconn__Job__c> newMap, Map<Id,dispconn__Job__c> oldMap){
        if (!firstRun) { return; }
        firstRun = false;
        Boolean customFormData = False;
        Set<Id> extJobIds = new Set<Id>();  

        for(dispconn__Job__c j: newList) {
            if (!String.isBlank(j.dispconn__Custom_Form_Data__c) && j.dispconn__Custom_Form_Data__c != oldMap.get(j.Id).dispconn__Custom_Form_Data__c) { 
                customFormData = True;
                extJobIds.add(j.Ext_Job__c);
            }
        } 
        map<String,Authorization_Form__c> mapAuth = new map<String,Authorization_Form__c>();
        if (customFormData) {
            // get auth record
            for(Authorization_Form__c a: [SELECT Work_Order__c,Id,Work_Order__r.Contractor__r.First_Hour_Labor_Rate__c FROM Authorization_Form__c WHERE Work_Order__c IN :extJobIds]) { //should only be 1
                mapAuth.put(a.Work_Order__c, a);
            }
        }         

        // Create a list for updating
        List<Work_Order__c> extJobsUpdate = new List<Work_Order__c>();
        List<Authorization_Form__c> extAuthsUpdate = new List<Authorization_Form__c>();
        // Let's update the Dispatch Job records with the changes in the trigger list
        for(dispconn__Job__c dispJob: newList) {
            Work_Order__c extJob = new Work_Order__c(Id=dispJob.Ext_Job__c);

            if (dispJob.dispconn__Status__c != oldMap.get(dispJob.Id).dispconn__Status__c) {
                if (dispJob.dispconn__Status__c == 'Accepted') {
                    extJob.Status__c = 'Accepted'; 
                    extJob.Dispatch_Status__c = 'Accepted'; 
                    extJob.Date_Accepted__c = DateTime.now(); 
                }    
                else if (dispJob.dispconn__Status__c == 'Rejected') {
                    String reason = dispJob.dispconn__Status_Message__c;
                    if (!String.IsBlank(reason)) {
                        reason = reason.toLowerCase();
                        if (reason == 'no availability') {
                            extJob.Status__c = 'Rejected: No availability'; 
                        } else if (reason == 'wrong trade') {
                            extJob.Status__c = 'Rejected: Wrong trade'; 
                        } else if (reason == 'billing issue') {
                            extJob.Status__c = 'Rejected: Billing issue'; 
                        } else if (reason == 'incorrect service area') {
                            extJob.Status__c = 'Rejected: Incorrect service area'; 
                        } 
                    }
                    extJob.Dispatch_Status__c = 'Rejected'; 
                }                 
                else if (dispJob.dispconn__Status__c == 'Paused') {
                    extJob.Status__c = 'Paused'; 
                    extJob.Dispatch_Status__c = 'Paused'; 
                    extJob.Date_Paused__c = DateTime.now(); 
                    if (!String.IsBlank(dispJob.dispconn__Status_Message__c)) {
                        extJob.Dispatch_Status_Reason__c = dispJob.dispconn__Status_Message__c;
                    }
                } 
                else if (dispJob.dispconn__Status__c == 'Completed') { 
                    extJob.Status__c = 'Completed'; 
                    extJob.Dispatch_Status__c = 'Completed'; 
                    extJob.Date_Completed__c = dispJob.dispconn__Completed_Time__c;
                    if (!String.IsBlank(dispJob.dispconn__Status_Message__c)) {
                        extJob.Dispatch_Status_Reason__c = dispJob.dispconn__Status_Message__c;
                    }
                }  
                else if (dispJob.dispconn__Status__c == 'Scheduled' && extJob.Date_Scheduled__c == null) { 
                    extJob.Status__c = 'Scheduled'; 
                    extJob.Dispatch_Status__c = 'Scheduled';
                    extJob.Date_Scheduled__c = DateTime.now();                     
                }
                else if (dispJob.dispconn__Status__c == 'Rescheduled' && extJob.Date_Rescheduled__c == null) { 
                    extJob.Status__c = 'Rescheduled'; 
                    extJob.Dispatch_Status__c = 'Rescheduled';
                    extJob.Date_Rescheduled__c = DateTime.now();                     
                }                            
                else if (dispJob.dispconn__Status__c == 'Enroute') { 
                    extJob.Status__c = 'Enroute'; 
                    extJob.Dispatch_Status__c = 'Enroute'; 
                    extJob.Date_Departed__c = dispJob.dispconn__Departed_Time__c;
                } else if (dispJob.dispconn__Status__c == 'Started') {
                    extJob.Status__c = 'Started'; 
                    extJob.Dispatch_Status__c = 'Started'; 
                    extJob.Date_Started__c = dispJob.dispconn__Started_Time__c;
                }
                else if (dispJob.dispconn__Status__c == 'Canceled') { 
                    extJob.Status__c = 'Canceled'; 
                    extJob.Dispatch_Status__c = 'Canceled'; 
                }    
            }

            if (dispJob.dispconn__Rating__c != oldMap.get(dispJob.Id).dispconn__Rating__c) { 
                extJob.Rating__c = dispJob.dispconn__Rating__c;
                extJob.Rating_Message__c = dispJob.dispconn__Rating_Message__c;
            }
            if (!String.isBlank(dispJob.dispconn__Custom_Form_Data__c) && dispJob.dispconn__Custom_Form_Data__c != oldMap.get(dispJob.Id).dispconn__Custom_Form_Data__c) { 
                try {
                    CustomFormObject customForm = (CustomFormObject)JSON.deserialize(dispJob.dispconn__Custom_Form_Data__c, CustomFormObject.class);
                    map<String, String> mapFormData = getFormDataMap(customForm.form_data);
                    if (customForm.form_name == 'autho1' && mapFormData.size() > 0 && getTruthyValue(mapFormData.get('send_for_approval')) == 'Yes') {
                        Authorization_Form__c extAuth = null;
                        if (mapAuth.size() > 0) {
                            extAuth = mapAuth.get(dispJob.Ext_Job__c); //use existing auth record, don't create a new one
                        }
                        if (extAuth == null) {
                            extAuth = new Authorization_Form__c();
                        }                        
                        extAuth.RecordTypeId = getStringValue(mapFormData.get('auth_type'),255);
                        extAuth.Work_Order__c = dispJob.Ext_Job__c;
                        extAuth.Brand__c = getStringValue(mapFormData.get('brand'),255);
                        extAuth.Model__c = getStringValue(mapFormData.get('model'),150);
                        extAuth.Serial__c = getStringValue(mapFormData.get('serial'),150);
                        extAuth.Age__c = getStringValue(mapFormData.get('age'),255);
                        extAuth.Condition__c = getStringValue(mapFormData.get('condition'),255);
                        extAuth.Issue_description__c = mapFormData.get('issue_description');
                        extAuth.Part_1__c = getStringValue(mapFormData.get('part_1'),150);
                        extAuth.Part_2__c = getStringValue(mapFormData.get('part_2'),150);
                        extAuth.Part_3__c = getStringValue(mapFormData.get('part_3'),150);
                        extAuth.Part_4__c = getStringValue(mapFormData.get('part_4'),150);
                        extAuth.Part_Number_Part_1__c = getStringValue(mapFormData.get('part_1_number'),150);
                        extAuth.Part_Number_Part_2__c = getStringValue(mapFormData.get('part_2_number'),150);
                        extAuth.Part_Number_Part_3__c = getStringValue(mapFormData.get('part_3_number'),150);
                        extAuth.Part_Number_Part_4__c = getStringValue(mapFormData.get('part_4_number'),150);
                        extAuth.Price_Part_1__c = getDecimalValue(mapFormData.get('part_1_price'));
                        extAuth.Price_Part_2__c = getDecimalValue(mapFormData.get('part_2_price'));
                        extAuth.Price_Part_3__c = getDecimalValue(mapFormData.get('part_3_price'));
                        extAuth.Price_Part_4__c = getDecimalValue(mapFormData.get('part_4_price'));
                        extAuth.Plumbing_Stoppage_Location_1__c = getStringValue(mapFormData.get('stoppage_location_1'),255);
                        extAuth.Plumbing_Stoppage_Location_2__c = getStringValue(mapFormData.get('stoppage_location_2'),255);
                        extAuth.Plumbing_Stoppage_Location_3__c = getStringValue(mapFormData.get('stoppage_location_3'),255);
                        extAuth.Plumbing_Stoppage_Location_4__c = getStringValue(mapFormData.get('stoppage_location_4'),255);
                        extAuth.Stoppage_1_Pricing__c = getDecimalValue(mapFormData.get('stoppage_location_1_price'));
                        extAuth.Stoppage_2_Pricing__c = getDecimalValue(mapFormData.get('stoppage_location_2_price'));
                        extAuth.Stoppage_3_Pricing__c = getDecimalValue(mapFormData.get('stoppage_location_3_price'));
                        extAuth.Stoppage_4_Pricing__c = getDecimalValue(mapFormData.get('stoppage_location_4_price'));
                        Decimal job_length_hours = getDecimalValue(mapFormData.get('job_length_hours'));
                        extAuth.How_long_will_the_job_take_minutes__c = job_length_hours == null ? null : job_length_hours*60;
                        if (extAuth.Work_Order__r.Contractor__r.First_Hour_Labor_Rate__c == null) { // only override if not specified on account
                            extAuth.Labor_Rate__c = getDecimalValue(mapFormData.get('labor_rate'));
                        }    
                        extAuth.Flat_Rate_Pricing__c  = getDecimalValue(mapFormData.get('flat_rate_pricing'));
                        extAuth.Tax__c  = getDecimalValue(mapFormData.get('tax'));
                        extAuth.Trip_Charge__c  = getDecimalValue(mapFormData.get('trip_charge'));
                        extAuth.Did_unit_have_any_previous_repairs__c  = getTruthyValue(mapFormData.get('previous_repairs'));
                        extAuth.Did_the_tech_collect_the_SCF__c  = getTruthyValue(mapFormData.get('scf_collect'));
                        extAuth.Rust_or_corrosion__c  = getTruthyValue(mapFormData.get('rust_or_corrosion'));
                        extAuth.Are_you_on_site_right_now__c  = getTruthyValue(mapFormData.get('on_site_now'));
                        extAuth.Can_the_job_be_done_today__c  = getTruthyValue(mapFormData.get('job_can_be_done_today'));
                        extAuth.Has_the_unit_been_maintained__c  = getTruthyValue(mapFormData.get('unit_been_maintained'));
                        extAuth.Is_the_unit_leaking_freon__c  = getTruthyValue(mapFormData.get('leaking_freon'));
                        extAuth.Is_the_Unit_leaking_water__c  = getTruthyValue(mapFormData.get('leaking_water'));
                        extAuth.What_was_the_cause_of_failure__c  = getStringValue(mapFormData.get('cause_of_failure'),255);

                        extAuthsUpdate.add(extAuth);
                    }
                } catch (Exception e) {
                    // do nothing - don't want a malformed json to break the integration. Or a text field where a numeric is expected etc.
                    system.debug('Dispatch: Error processing custom form: '+e.getMessage());
                }

            }
            extJobsUpdate.add(extJob);
        }
        if (!extJobsUpdate.isEmpty()) {
            upsert extJobsUpdate;
        }
        if (!extAuthsUpdate.isEmpty()) {
            upsert extAuthsUpdate;
        }        
    }

    public static map<String, String> getFormDataMap(List<FormDataObject> form_data) {
        map<String, String> mapFormData = new map<String, String>();
        for(FormDataObject fdo: form_data) {
            mapFormData.put(fdo.name,fdo.value);
        }
        return mapFormData;
    }

    public static String getStringValue(String value, Integer maxLength) {
        if (!String.isBlank(value)) {
            return value.left(maxLength);
        } else {
            return null;
        }
    }

    public static Decimal getDecimalValue(String value) {
        if (!String.isBlank(value)) {
            return Decimal.valueOf(value.replaceAll('[^0-9.]', ''));
        } else {
            return null;
        }
    }    

    public static Integer getIntegerValue(String value) {
        if (!String.isBlank(value)) {
            return Integer.valueOf(math.round(Decimal.valueOf(value)));
        } else {
            return null;
        }
    }  

    public static String getTruthyValue(String value) {
        if (!String.isBlank(value)) {
            return value == 'true' ? 'Yes' : 'No';
        } else {
            return null;
        }
    }          

    public static void AuthorizationForm(List<Authorization_Form__c> newList,List<Authorization_Form__c> oldList, Map<Id,Authorization_Form__c> newMap, Map<Id,Authorization_Form__c> oldMap){
        if (!firstRun) { return; }
        List<Work_Order__c> extJobsUpdate = new List<Work_Order__c>();
        for(Authorization_Form__c authForm: newList) {
            if (authForm.Authorization_Status__c != oldMap.get(authForm.Id).Authorization_Status__c) {
                Work_Order__c extJob = new Work_Order__c(Id=authForm.Work_Order__c);
                extJob.Auth_Approval_Status__c = authForm.Authorization_Status__c;
                extJobsUpdate.add(extJob);
            }
        }
        if (!extJobsUpdate.isEmpty()) {
            update extJobsUpdate;
        }
        firstRun = false;
    }

    public static void DispatchNoteFromToDispatch(List<Note> newList){
        if (!firstRun) { return; }
        firstRun = false;
        
        // Gather Note Parent Ids 
        map<string, Note> mapDispNotes = new map<string, Note>();
        map<string, Note> mapExtNotes = new map<string, Note>();
        for(Note note: newList) {
            if (note.Id != Null && note.ParentId != Null) {
                Schema.sObjectType entityType = note.parentId.getSObjectType();
                system.debug('Note Entity: '+entityType);
                if (entityType == dispconn__Job__c.sObjectType) {
                    mapDispNotes.put(note.ParentId, note);
                }
                //if (entityType == ServiceAppointment.sObjectType) {
                //    mapExtNotes.put(note.ParentId, note);
                //}                
            }
        }
        if (mapDispNotes.size()>0) {
            // Get Dispatch Job records based on Note Parent Ids
            List<dispconn__Job__c> dispJobs = [SELECT Ext_Job__c FROM dispconn__Job__c WHERE Id IN :mapDispNotes.KeySet()];
            List<Field_Note__c> extNoteList = new List<Field_Note__c>();

            // This section copies notes from the Dispatch job to the source job
            for(dispconn__Job__c dj: dispJobs) {
                // Go back and get the Note record
                Note dispNote = mapDispNotes.get(dj.Id);
                
                Field_Note__c n = new Field_Note__c();
                n.Work_Order__c = dj.Ext_Job__c;
                n.Name = dispNote.Title;
                if (dispNote.Body.left(4) == 'http') {
                    n.Link__c = dispNote.Body;
                } else {    
                    n.Body__c = dispNote.Body;
                }    

                // Add new Note to the list
                extNoteList.add(n);            
            }
            if(extNoteList.size() > 0) {
                insert extNoteList;
            }            
        }    

   
    }    

}