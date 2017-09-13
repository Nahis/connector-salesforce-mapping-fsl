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

    public static void DispatchServiceProviderToDispatch(List<ServiceTerritory> newList,List<ServiceTerritory> oldList, Map<Id,ServiceTerritory> newMap, Map<Id,ServiceTerritory> oldMap){
        if (!firstRun) { return; }
        firstRun = false;
        // Gather Location Ids
        List<ServiceTerritory> newListRelevant = new List<ServiceTerritory>();
        Set<Id> locationIds = new Set<Id>();
        for(ServiceTerritory loc: newList) {
            if (loc.Dispatch_me__c) {
                locationIds.add(loc.Id);
                newListRelevant.add(loc);
            }
        }

        if (newListRelevant.size() > 0 ) {
            // Get Dispatch Service Provider records based on Location Ids and put in map
            List<dispconn__Service_Provider__c> dispSPs = [SELECT Id, Ext_Service_Provider__c FROM dispconn__Service_Provider__c WHERE Ext_Service_Provider__c IN :locationIds];
            map<string, dispconn__Service_Provider__c> mapDispSPs = new map<string, dispconn__Service_Provider__c>();
            for(dispconn__Service_Provider__c sp: dispSPs) {
                mapDispSPs.put(sp.Ext_Service_Provider__c, sp);
            }  

            // Create a list for updating
            List<dispconn__Service_Provider__c> dispSPsUpdate = new List<dispconn__Service_Provider__c>();
            
            for (ServiceTerritory extSP : newListRelevant) {
                if (extSP.Dispatch_me__c) { //if not flagged as a dispatch.me org
                    
                    //lookup corresponding Dispatch Service Provider from map
                    dispconn__Service_Provider__c dispSP;
                    dispSP = mapDispSPs.get(extSP.Id);
                    if (dispSP == Null) {
                        // SP not found insert
                        dispSP = new dispconn__Service_Provider__c(); 
                    }    

                    /***********
                     * MAPPING START:
	                 * Update this section with mapping changes to your specific instance. 
	                 * 'extSP' contains the fields to your service provider entity. Map those fields to
	                 * 'dispSP' which is the corresponding dispconn entity
	                 */

                    dispSP.Name = extSP.Name; // If the name field is "technical" map it from other fields e.g. 'Your Company Name ('+extSP.City__c+')';
                    dispSP.dispconn__Phone__c = extSP.Phone__c;
                    dispSP.dispconn__Email__c = extSP.Email__c;
                    dispSP.dispconn__Usage__c = 'normal';
                    // need all 4 address components to have a valid address
                    if (String.isBlank(extSP.Street) || String.isBlank(extSP.City) || String.isBlank(extSP.State) || String.isBlank(extSP.PostalCode) ) {
                        dispSP.dispconn__Address_Street__c      = null;
                        dispSP.dispconn__Address_City__c        = null;
                        dispSP.dispconn__Address_State__c       = null;
                        dispSP.dispconn__Address_Postal_Code__c = null;
                    } else {
                        dispSP.dispconn__Address_Street__c      = extSP.Street;
                        dispSP.dispconn__Address_City__c        = extSP.City;
                        dispSP.dispconn__Address_State__c       = extSP.State;
                        dispSP.dispconn__Address_Postal_Code__c = extSP.PostalCode;
                    }
                    /***********
                     * MAPPING END 
                     */
                    
                    dispSP.Ext_Service_Provider__c = extSP.Id;
                    // Add Service Provider to the list
                    dispSPsUpdate.add(dispSP);
                }
            }
            // If there are Service Provider records, then apply updates
            if(dispSPsUpdate.size() > 0) {
                upsert dispSPsUpdate;
            }
        }    
    }

    public static void DispatchTechToDispatch(List<ServiceResource> newList,List<ServiceResource> oldList, Map<Id,ServiceResource> newMap, Map<Id,ServiceResource> oldMap) {
        if (!firstRun) { return; }
        firstRun = false;

        // Gather Resource Ids
        List<ServiceResource> newListRelevant = new List<ServiceResource>();
        Set<Id> resourceIds = new Set<Id>();
        Set<Id> userIds = new Set<Id>();
        for(ServiceResource sr: newList) {
            if (sr.Dispatch_Me__c && (sr.ResourceType == 'T' || sr.ResourceType == 'D')) {  //if you want to control which employees become dispatch users. If all users under an enabled service provider then replace this condition with a check on service provider flag
                resourceIds.add(sr.Id);
                userIds.add(sr.RelatedRecordId);
                newListRelevant.add(sr);
            }
        }
        if (newListRelevant.size() > 0 ) {
            // Get Dispatch Field Worker records based on Resource Ids and put in map
            List<dispconn__Field_Tech__c> dispTechs = [SELECT Id, Ext_Tech__c, dispconn__Service_Provider__c
                                                         FROM dispconn__Field_Tech__c 
                                                         WHERE Ext_Tech__c IN :resourceIds];
            map<string, dispconn__Field_Tech__c> mapDispTechs = new map<string, dispconn__Field_Tech__c>();
            for(dispconn__Field_Tech__c t: dispTechs) {
                mapDispTechs.put(t.Ext_Tech__c, t);
            }

            /***********
             * BULK QUERY MAPPING START:
             * Add bulkified queries to get the data that you need into maps
             */

            // Get service territories based on Resource Ids and put in map
            List<ServiceTerritoryMember> extServiceTerritories = [SELECT ServiceTerritoryId, ServiceResourceId FROM ServiceTerritoryMember WHERE ServiceResourceId IN :resourceIds
                                                                  AND TerritoryType = 'P' AND EffectiveEndDate = Null AND ServiceTerritory.Dispatch_Me__c = True];
            map<string, ServiceTerritoryMember> mapExtServiceTerritories = new map<string, ServiceTerritoryMember>();
            Set<Id> locationIds = new Set<Id>();
            for(ServiceTerritoryMember st: extServiceTerritories) {
                mapExtServiceTerritories.put(st.ServiceResourceId, st);
                locationIds.add(st.ServiceTerritoryId);
            }

            // Get Dispatch Service Provider records based on the Location IDs and put in map
            List<dispconn__Service_Provider__c> dispSPs = [SELECT Id, Ext_Service_Provider__c 
                                                           FROM dispconn__Service_Provider__c 
                                                           WHERE Ext_Service_Provider__c IN :locationIds];
            map<string, dispconn__Service_Provider__c> mapDispSPs = new map<string, dispconn__Service_Provider__c>();
            for(dispconn__Service_Provider__c sp: dispSPs) {
                mapDispSPs.put(sp.Ext_Service_Provider__c, sp);
            }            

            // Get users and put in map
            List<User> extUsers = [SELECT Id,FirstName,LastName,Email,MobilePhone FROM User WHERE Id IN :userIds];
            map<string, User> mapExtUsers = new map<string, User>();
            for(User u: extUsers) {
                mapExtUsers.put(u.Id, u);
            }  
            /***********
             * BULK QUERY MAPPING END 
             */  

            // Create a list for updating
            List<dispconn__Field_Tech__c> dispTechsUpdate = new List<dispconn__Field_Tech__c>();
            
            // Process Trigger Records
            for (ServiceResource extTech : newListRelevant) {
                try {
                    /***********
                     * MAPPING START:
                     * Update this section with mapping changes to your specific instance. 
                     * 'extTech' contains the fields to your field tech/worker entity. Map those fields to
                     * 'dispTech' which is the corresponding dispconn entity
                     */

                    //lookup corresponding Dispatch Field Worker from map
                    dispconn__Field_Tech__c dispTech;
                    dispTech = mapDispTechs.get(extTech.Id);
                    if (dispTech == Null) {
                        // Tech not found insert
                        dispTech = new dispconn__Field_Tech__c(); 
                    }   

                    //lookup corresponding Service Territory from map
                    ServiceTerritoryMember stm;
                    stm = mapExtServiceTerritories.get(extTech.Id);
                    if (stm == Null) {
                        throw new spException('Member is not linked to a valid Service Territory');
                    } 

                    //lookup corresponding Dispatch Service Provider from map
                    dispconn__Service_Provider__c sp;
                    sp = mapDispSPs.get(stm.ServiceTerritoryId);
                    if (sp == Null) {
                        throw new spException('Service Provider does not exist in Dispatch entity');
                    }
                    dispTech.dispconn__Service_Provider__c = sp.Id;

                    //lookup corresponding user from map
                    User u;
                    u = mapExtUsers.get(extTech.RelatedRecordId);
                    if (u == Null) {
                        throw new techException('Linked user not active');
                    } 
                    dispTech.dispconn__First_Name__c = u.FirstName;
                    dispTech.dispconn__Last_Name__c  = u.LastName;
                    dispTech.dispconn__Email__c = u.Email;
                    dispTech.dispconn__Phone__c = u.MobilePhone;
                    dispTech.dispconn__View_Other_Tech_Schedules__c = False;
                    //if (extTech.Dispatch_Portal_Access__c) {
                    if (extTech.ResourceType == 'D') {
                        dispTech.dispconn__View_Other_Tech_Schedules__c = True;
                    }
                    dispTech.dispconn__Active__c = extTech.IsActive;
                    /***********
                     * MAPPING END 
                     */

                    dispTech.Ext_Tech__c  = extTech.Id;
                    dispTechsUpdate.add(dispTech);   

                } catch (techException e) {
                    // do nothing as SP not yet set up
                    system.debug(e.getMessage());
                } catch (spException l) {
                    // do nothing as SP not yet set up
                    system.debug(l.getMessage());
                } 
            }
            // If there are tech records, then apply updates & inserts
            if(dispTechsUpdate.size() > 0) {
                upsert dispTechsUpdate;
            }
        }
    }

    public static void DispatchJobToDispatch(List<ServiceAppointment> newList,List<ServiceAppointment> oldList, Map<Id,ServiceAppointment> newMap, Map<Id,ServiceAppointment> oldMap){
        if (!firstRun) { return; }
        firstRun = false;

        String assignMethod = dispconn__Dispatch_CS__c.getInstance('DISPATCH_ASSIGN_METHOD').dispconn__Value__c;
        Set<Id> jobIds = new Set<Id>();    
        Set<Id> contactIds = new Set<Id>();    
        Set<Id> locationIds = new Set<Id>();    
        List<ServiceAppointment> newListRelevant = new List<ServiceAppointment>();
        for(ServiceAppointment sa: newList) {
            if ((assignmethod == 'SPOFFER' && sa.ServiceTerritoryId != null) || // if using the offer method, the Service Territory should be on the appointment
                (assignMethod == 'TECHASSIGN' || sa.Status != 'None')) {         // if using the direct assign method then wait until scheduled in FSL
           
                jobIds.add(sa.Id);
                if (sa.ContactId != null) {
                    contactIds.add(sa.ContactId);
                }    
                if (sa.ServiceTerritoryId != null) {
                    locationIds.add(sa.ServiceTerritoryId);
                    // could also put in a check here to see if the Service Territory is DispatchMe - before adding to newListRelevant. Would need another bulkified query
                }                    
                newListRelevant.add(sa);
            }
        }
        
        if (newListRelevant.size() > 0 ) {
            // Get Dispatch Jobs records based on Job Ids and put in map
            List<dispconn__Job__c> dispJobs = [SELECT Id, Ext_Job__c, dispconn__Field_Tech__c FROM dispconn__Job__c WHERE Ext_Job__c IN :jobIds];
            map<string, dispconn__Job__c> mapDispJobs = new map<string, dispconn__Job__c>();
            for(dispconn__Job__c j: dispJobs) {
                mapDispJobs.put(j.Ext_Job__c, j);
            }
            // Get list of locations sending jobs to dispatch - in this example it needs to be obtained via the assigned resource 
            // first get assigned resources, then get territory from resource       
            List<AssignedResource> extResources = [SELECT Id,ServiceAppointmentId,ServiceResourceId,ServiceResource.RelatedRecord.IsActive,ServiceResource.Dispatch_Me__c
                                                   FROM AssignedResource 
                                                   WHERE ServiceAppointmentId IN :jobIds];
            Set<Id> resourceIds = new Set<Id>();
            map<string, AssignedResource> mapExtResources = new map<string, AssignedResource>();
            for(AssignedResource r: extResources) {
                // if resource is an active dispatch user
                mapExtResources.put(r.ServiceAppointmentId, r);
                resourceIds.add(r.ServiceResourceId);
            }
            // Get service territories based on Resource Ids and put in map
            List<ServiceTerritoryMember> extLocations = [SELECT ServiceTerritoryId, ServiceResourceId 
                                                         FROM ServiceTerritoryMember 
                                                         WHERE ServiceResourceId IN :resourceIds AND TerritoryType = 'P' 
                                                         AND EffectiveEndDate = Null AND ServiceTerritory.Dispatch_Me__c = True];
            map<string, ServiceTerritoryMember> mapExtLocations = new map<string, ServiceTerritoryMember>();
            for(ServiceTerritoryMember t: extLocations) {
                mapExtLocations.put(t.ServiceResourceId, t);
            }   


            // Gather Contact Info for job. This assumes the address is stored on the contact.
            List<Contact> contacts = [SELECT FirstName, LastName, MobilePhone, Email,
                                             MailingStreet, MailingCity, MailingPostalCode, MailingState, MailingCountry
                                       FROM Contact WHERE Id IN :contactIds];
            map<Id, Contact> mapContacts = new map<Id, Contact>(contacts);

            // Get Dispatch Field Worker records based on Resource Ids and put in map
            List<dispconn__Field_Tech__c> dispTechs = [SELECT Id, Ext_Tech__c, dispconn__Service_Provider__c
                                                         FROM dispconn__Field_Tech__c 
                                                         WHERE Ext_Tech__c IN :resourceIds AND dispconn__Active__c = True];
            map<string, dispconn__Field_Tech__c> mapDispTechs = new map<string, dispconn__Field_Tech__c>();
            for(dispconn__Field_Tech__c t: dispTechs) {
                mapDispTechs.put(t.Ext_Tech__c, t);
            }        

            // Get Dispatch Service Provider records based on the Location IDs on the ServiceAppointment and put in map
            // This query is only required if the assignment method is to Service Providers (offer) otherwise this value would be obtained from dispTechs
            List<dispconn__Service_Provider__c> dispSPs = [SELECT Id, Ext_Service_Provider__c 
                                                           FROM dispconn__Service_Provider__c 
                                                           WHERE Ext_Service_Provider__c IN :locationIds];
            map<string, dispconn__Service_Provider__c> mapDispSPs = new map<string, dispconn__Service_Provider__c>();
            for(dispconn__Service_Provider__c sp: dispSPs) {
                mapDispSPs.put(sp.Ext_Service_Provider__c, sp);
            }
            // Create a list for updating
            List<dispconn__Job__c> dispJobsUpdate = new List<dispconn__Job__c>();

            for (ServiceAppointment extJob : newListRelevant) {
                try {
                    System.debug('Dispatch: ' + extJob.AppointmentNumber);
                    dispconn__Job__c dispJob;
                    dispJob = mapDispJobs.get(extJob.Id);
                    if (dispJob == Null) {
                        // job not found insert
                        dispJob = new dispconn__Job__c();
                        dispJob.dispconn__Status__c = 'New';
                    }
                    dispJob.Ext_Job__c = extJob.Id;
                    dispJob.dispconn__Last_Sync_Response__c = 'Pending Sync:'+DateTime.now();
                    dispJob.dispconn__Synced__c = False;
                    
                    // if using the direct tech assignment method then map the field tech
                    if (assignMethod == 'TECHASSIGN') {
                        // Try to get assigned resource
                        AssignedResource ar = mapExtResources.get(extJob.Id);
                        if (ar == null) {  // not assigned or unassigned
                            throw new jobException('Dispatch: job not assigned to resource');
                        }
                        
                        dispconn__Field_Tech__c dispTech;
                        dispTech = mapDispTechs.get(ar.ServiceResourceId);

                        if (dispJob == null) {
                            if (dispTech == null) {
                                if (extJob.ServiceTerritoryId == null) { //don't know which territory it is from the job
                                    throw new jobException('Dispatch: Job is unassigned and does not yet exist in Dispatch');
                                }    
                            } else { // new assigned job
                                dispJob.dispconn__Field_Tech__c = dispTech.Id;
                            }
                        } else {
                            if (dispTech == null) { //must've been unassigned
                                dispJob.dispconn__Field_Tech__c = null;
                            } else {
                                dispJob.dispconn__Field_Tech__c = dispTech.Id; //assign or re-assign
                            }
                        }                        
                        // if service territory not on the service appointment get it from the assignment record
                        if (extJob.ServiceTerritoryId == null) { 
                            ServiceTerritoryMember t = mapExtLocations.get(ar.ServiceResourceId);
                            if (t == null) {  // not a valid dispatch territory
                                throw new jobException('Dispatch: not a valid dispatch territory 1');
                            }
                            dispJob.dispconn__Service_Provider__c = dispTech.dispconn__Service_Provider__c;                 
                        }                        
                    }    

                    // if service territory on the service appointment get it from there
                    if (extJob.ServiceTerritoryId != null) {
                        dispconn__Service_Provider__c sp = mapDispSPs.get(extJob.ServiceTerritoryId);
                        if (sp == null) {  // not a valid dispatch territory
                            throw new jobException('Dispatch: not a valid dispatch territory 2');
                        }                        
                        dispJob.dispconn__Service_Provider__c = sp.Id;
                    }

                    /* CONTACT INFO */
                    Contact c = mapContacts.get(extJob.ContactId);
                    if (c == null) {
                        throw new jobException('Contact not linked to the job');
                    }
                    dispJob.dispconn__First_Name__c = c.FirstName;
                    dispJob.dispconn__Last_Name__c = c.LastName;
                    String mobilePhone = c.MobilePhone;
                    if (!String.isBlank(mobilePhone)) {
                        dispJob.dispconn__Mobile__c = mobilePhone.left(14);
                    }
                    if (!String.isBlank(c.Email)) {
                        dispJob.dispconn__Email__c = c.Email;
                    }

                    /* JOB ADDRESS */
                    dispJob.dispconn__Address_Country__c = 'United States';
                    if (extJob.Street == null) { // if address on service appointment is null, get it from linked contact
                        dispJob.dispconn__SF_Job_Id__c = extJob.AppointmentNumber; 
                        dispJob.dispconn__Address_Street__c      = c.MailingStreet;
                        dispJob.dispconn__Address_City__c        = c.MailingCity;
                        dispJob.dispconn__Address_State__c       = c.MailingState;
                        dispJob.dispconn__Address_Postal_Code__c = c.MailingPostalCode;
                        if (c.MailingCountry == 'CA' ) {
                            dispJob.dispconn__Address_Country__c = 'Canada';
                        }    
                    } else {
                        dispJob.dispconn__SF_Job_Id__c = extJob.AppointmentNumber; 
                        dispJob.dispconn__Address_Street__c      = extJob.Street;
                        dispJob.dispconn__Address_City__c        = extJob.City;
                        dispJob.dispconn__Address_State__c       = extJob.State;
                        dispJob.dispconn__Address_Postal_Code__c = extJob.PostalCode;
                        if (c.MailingCountry == 'CA' ) {
                            dispJob.dispconn__Address_Country__c = 'Canada';
                        }                        
                    }                   

                    /* JOB TITLE */
                    if (!String.isBlank(extJob.Subject)) {
                        dispJob.dispconn__Title__c = extJob.Subject;
                    }  

                    /* JOB DESCRIPTION */
                    System.debug('Dispatch: description');
                    String descr = extJob.Description;
                    dispJob.dispconn__Description__c = descr;

                    /* SERVICE TYPE */
                    /*if (!String.isBlank(extJob.WorkType)) {
                            dispJob.dispconn__Service_Type__c = extJob.WorkType;
                    } */   
                    
                    if (extJob.SchedStartTime != null) {
                        dispJob.dispconn__Scheduled_Date__c = extJob.SchedStartTime;
                        dispJob.dispconn__Estimated_Duration__c = extJob.Duration;
                    }    
                    // handle status changes
                    if (oldMap == null || extJob.Status != oldMap.get(extJob.Id).Status) {
                        /*
                        if (extJob.SchedStartTime != oldMap.get(extJob.Id).SchedStartTime || extJob.SchedEndTime != oldMap.get(extJob.Id).SchedEndTime || extJob.Duration != oldMap.get(extJob.Id).Duration ) {
                            dispJob.dispconn__Status__c = 'Scheduled';
                        } */                           
                        if (extJob.Status == 'Completed' ) {
                            dispJob.dispconn__Status__c = 'Completed';
                        } else if (extJob.Status == 'Canceled') { 
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

        /*
        This next section only relevant for FSL: here we are trying to retrieve the tech record for the organization so we can assign it to view it on the gantt.
        It assumes a 1-1 relationship i.e. 3rd party contractor org will only have a single member. 
        This logic is not necessary for most cases
        */
        map<string, dispconn__Service_Provider__c> mapDispSPs = new map<string, dispconn__Service_Provider__c>();
        map<string, ServiceTerritoryMember> mapExtTechs = new map<string, ServiceTerritoryMember>();
        String assignMethod = dispconn__Dispatch_CS__c.getInstance('DISPATCH_ASSIGN_METHOD').dispconn__Value__c;
        if (assignMethod == 'SPOFFER') {
            Set<Id> spIds = new Set<Id>();    
            for(dispconn__Job__c j: newList) {
                if (j.dispconn__Service_Provider__c != null) {
                    spIds.add(j.dispconn__Service_Provider__c);
                }    
            }
            Set<Id> locationIds = new Set<Id>();    
            List<dispconn__Service_Provider__c> dispSPs = [SELECT Id,Ext_Service_Provider__c FROM dispconn__Service_Provider__c WHERE Id IN :spIds];
            for(dispconn__Service_Provider__c sp: dispSPs) {
                mapDispSPs.put(sp.Id, sp);
                locationIds.add(sp.Ext_Service_Provider__c);
            }

            // This relationship is assumed to be 1-1 which should be a good assumption for this setup
            List<ServiceTerritoryMember> extTechs = [SELECT ServiceTerritoryId,ServiceResourceId FROM ServiceTerritoryMember WHERE ServiceTerritoryId IN :locationIds];
            for(ServiceTerritoryMember t: extTechs) {
                mapExtTechs.put(t.ServiceTerritoryId, t);
            }
        }    

        // Create a list for updating
        List<ServiceAppointment> extJobsUpdate = new List<ServiceAppointment>();
        List<AssignedResource> extResourcesUpdate = new List<AssignedResource>();
        List<ServiceAppointmentHistory> extHistoryUpdate = new List<ServiceAppointmentHistory>();

        // Let's update the Dispatch Job records with the changes in the trigger list
        for(dispconn__Job__c dispJob: newList) {
            // Start a Service Work Order record with key if existing or not
            ServiceAppointment extJob = new ServiceAppointment(Id=dispJob.Ext_Job__c);

            // Apply Dispatch Job status info to Service Work Order record for Insert or Update
            if (dispJob.dispconn__Status__c == 'Accepted') {
                extJob.Third_Party_Accepted__c = DateTime.now(); 
            }    
            else if (dispJob.dispconn__Status__c == 'Completed' && (dispJob.dispconn__Status__c != oldMap.get(dispJob.Id).dispconn__Status__c)) { 
                //extJob.Dispatch_Completed_Time__c = dispJob.dispconn__Completed_Time__c;
                extJob.Status = 'Completed'; 
                //if (!String.IsBlank(dispJob.dispconn__Status_Message__c)) {
                //    extJob.Dispatch_Status_Reason__c = dispJob.dispconn__Status_Message__c;
                //}
            /* FSL: not handling for this case
                } else if (dispJob.dispconn__Status__c == 'Paused' && (dispJob.dispconn__Status__c != oldMap.get(dispJob.Id).dispconn__Status__c)) {
                extJob.Status = 'Paused';
                if (!String.IsBlank(dispJob.dispconn__Status_Message__c)) {
                    extJob.Dispatch_Status_Reason__c = dispJob.dispconn__Status_Message__c;
                }
            */
            }  
            else if (dispJob.dispconn__Status__c == 'Scheduled') { 
                //this should only be relevant if using offer model
                extJob.Status = 'Scheduled';
                // if schedule has changed
                if (oldMap == null || (dispJob.dispconn__Scheduled_Date__c != oldMap.get(dispJob.Id).dispconn__Scheduled_Date__c || 
                                    dispJob.dispconn__Estimated_Duration__c != oldMap.get(dispJob.Id).dispconn__Estimated_Duration__c) ) {

                  extJob.SchedStartTime = dispJob.dispconn__Scheduled_Date__c;
                  extJob.SchedEndTime = dispJob.dispconn__Scheduled_Date__c.addMinutes(Integer.valueOf(dispJob.dispconn__Estimated_Duration__c*60));
                  extJob.Duration = dispJob.dispconn__Estimated_Duration__c;
                }
                // see corresponding section in bulkified query
                if (assignMethod == 'SPOFFER') {
                    dispconn__Service_Provider__c dispSP = mapDispSPs.get(dispJob.dispconn__Service_Provider__c);
                    ServiceTerritoryMember extTech = mapExtTechs.get(dispSP.Ext_Service_Provider__c);
                    AssignedResource ar = new AssignedResource();
                    ar.ServiceResourceId = extTech.ServiceResourceId;
                    ar.ServiceAppointmentId = dispJob.Ext_Job__c;
                    extResourcesUpdate.add(ar);
                }

            }            
            else if (oldMap == null || (dispJob.dispconn__Status__c != oldMap.get(dispJob.Id).dispconn__Status__c)) {
                if (dispJob.dispconn__Status__c == 'Enroute') {
                    extJob.Status = 'Dispatched'; 
                    //extJob.Dispatch_Departed_Time__c = dispJob.dispconn__Departed_Time__c;
                } else if (dispJob.dispconn__Status__c == 'Started') {
                    extJob.Status = 'In Progress'; 
                    //extJob.Dispatch_Started_Time__c = dispJob.dispconn__Started_Time__c;
                }
            }
            else if (dispJob.dispconn__Status__c == 'Canceled' && (dispJob.dispconn__Status__c != oldMap.get(dispJob.Id).dispconn__Status__c)) { 
                //extJob.Dispatch_Completed_Time__c = dispJob.dispconn__Completed_Time__c;
                extJob.Status = 'Canceled'; 
            }    

            if (dispJob.dispconn__Rating__c != oldMap.get(dispJob.Id).dispconn__Rating__c) { 
                extJob.Dispatch_Rating__c = dispJob.dispconn__Rating__c;
                extJob.Dispatch_Rating_Message__c = dispJob.dispconn__Rating_Message__c;
            }
            // Add Service Work Order record to list
            extJobsUpdate.add(extJob);
        }
        if (!extJobsUpdate.isEmpty()) {
            upsert extJobsUpdate;
        }
        if (!extResourcesUpdate.isEmpty()) {
            try {
                insert extResourcesUpdate;
            } catch (Exception e)  {
                //ignore unique violation error
            }
        }        
    }

    public static void DispatchNoteFromToDispatch(List<Note> newList){
        if (!firstRun) { return; }
        firstRun = false;
        
        // Gather Note Parent Ids for Dispatch Jobs
        map<string, Note> mapNotes = new map<string, Note>();
        for(Note nte: newList) {
            if (nte.Id != Null && nte.ParentId != Null) {
                Schema.sObjectType entityType = nte.parentId.getSObjectType();
                system.debug('\n\n !!!! Note Entity: '+entityType);
                if (entityType == dispconn__Job__c.sObjectType) {
                    mapNotes.put(nte.ParentId, nte);
                }
            }
        }
        // Get Dispatch Job records based on Note Parent Ids
        List<dispconn__Job__c> dispJobs = [SELECT Id, Ext_Job__c FROM dispconn__Job__c WHERE Id IN :mapNotes.KeySet()];
        // Create a list for Inserting
        //List<Note> noteList = new List<Note>();  // In FSL there is no notes entity so instead we're using a custom entity on the next line
        List<Service_Appointment_Note__c> noteList = new List<Service_Appointment_Note__c>();
        for(dispconn__Job__c dj: dispJobs) {
            // Go back and get the Note record
            Note sourceNote = mapNotes.get(dj.Id);
            
            /* In FSL there is no notes entity under Service Appointment so we instead created a custom one. Most cases there should be a notes entity and if so use this section
            // Create a New Note and Copy
            Note n = new Note();
            n.ParentId = dj.Ext_Job__c;
            n.Title = sourceNote.Title;
            n.Body = sourceNote.Body;
            // Add new Note to the list
            noteList.add(n);
            */
            // Create a New Note and Copy
            Service_Appointment_Note__c n = new Service_Appointment_Note__c();
            n.Service_Appointment__c = dj.Ext_Job__c;
            n.Name = sourceNote.Title;
            if (sourceNote.Body.left(4) == 'http') {
                n.Link__c = sourceNote.Body;
            } else {    
                n.Body__c = sourceNote.Body;
            }    
            // Add new Note to the list
            noteList.add(n);            
        }
        // If there are Note records, then apply Inserts
        if(noteList.size() > 0) {
            insert noteList;
        }
    }    
}