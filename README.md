# Overview
This is the mapping between Dispatch Connect and Field Service Lightning (FSL). It also serves as a template for mapping using Dispatch Connect. **That is, the code examples and this documentation will walk you through mapping your own Salesforce implementation to Dispatch regardless of what objects you are using, customizations you have made or 3rd party tool that you are using. You heard right - you can connect your Salesforce instance to Dispatch no matter what you have done with Salesforce!** In addition, we use entirely custom objects so you will not be incurring additional license costs either. And it's easy too! Read on to find out why.

The following diagram gives a high level overview:

![Dispatch Connect Salesforce App](https://user-images.githubusercontent.com/8817368/43160886-1b2f9d96-8f8f-11e8-95f7-f8edbf9704f4.png)


# Dispatch Connect
A pre-requisite is to install the Dispatch Connect managed package into your instance. Please refer to this [documentation](https://www.dropbox.com/s/p3yze2sr0vrs52g/Salesforce%20App%20Installation%20Document.docx?dl=0) in order to get started.

In short, Dispatch Connect knows how to work with the Dispatch APIs. Which means you do not have to. The only thing you need to know is how to map from Salesforce to... Salesforce! If you can do that, then you have all the technology requirements to get going. And in case you are concerned - Dispatch Connect respects Salesforce Governer Limits. It does no additional queries and all DML actions are bulkified.

Dispatch Connect installs a few objects into your Salesforce instance which users do not have to even be aware of, let alone access. In fact, you can install the managed package in "Administrator Only" mode. But just so you know, the objects which it adds are:
* Dispatch Service Provider (dispconn__service_provider) - Stores the Contractor/Service Provider/Third Party/Franchise record
* Dispatch Field Worker (dispconn__field_tech) - stores the field worker/tech/dispatcher record. Only used when using the "Direct Assign" method (more on that later)
* Dispatch Job (dispconn__job) - stores the job/work order/service order record
* Dispatch Appointment (dispconn__appointment) - stores data at the appointment level if you need this granularity. By default it will not store data at this level.
* Global Dispatch Connect Settings (dispconn__Dispatch__CS)
* Job Offer settings (dispconn__DispatchJobOfferSettings)
* Dispatch Webhook (dispconn__Dispatch_Webhook) - stores webhook updates sent back from Dispatch and processes them to the Dispatch Job. Data is ephemeral.

# Dispatch-Field Service Lightning (FSL) - Business Case
FSL is Salesforce's own field service product. We don't compete with FSL we complement it! Just as we may complement or augment any other field service initiatives that you already might have on the Salesforce platform. In the FSL case, we add support for the "FSL for non-dedicated Third Party Contractors" business model. That is, while FSL works well for internal work forces and perhaps even for contractors it may struggle just a little bit with non-dedicated Third Party Contractors (TPC). 

TPCs are typically contractors that service companies might tap into for performing all their work or to backfill when the workload is high or to cover certain geographies. A TPC is it's own organization and the service company typically does not have the insight that they have when working with internal organizations. They won't know their availability or perhaps even the number of employees they have on board. In addition, TPCs also want to manage their own service business and even if we assume they are given a license they will not want to have to continuously perform swivel chair updates!

Lastly, and perhaps most importantly, are licensing concerns. Costs might be slightly prohibitive to provision a license for each TPC - remember that these TPCs typically only work for the parent company in a partial manner and a TPC may have 3 or 300 employees. Having to provision a Salesforce license for each of those cases may well be, um, a problem.

The good news is that this just happens to be where Dispatch excels! Enter "FSL for non-dedicated Third Party Contractors".

# Dispatch-Field Service Lightning (FSL) - Mapping
This github project contains the mapping used to facilitate what has been described in the business case. Please also take a look [at the setup and operation videos](https://www.screencast.com/t/CiMaaGmY) in order to bring it to life. These are referenced throughout the code comments.

# Assign Method
At a high level there are 2 different types of methods that you'll be using to assign work. This is one of the settings that you'll be entering as part of the initial setup:

* Assign to TPC (`SPOFFER`) - This is the typical third party contractor assignment. That is, you use a third party for fulfilling work and you assign the job to the organization, not the individual field worker. In most cases, you don't really care which field worker does the work as long as you are receiving updates and the customer is satisfied (or if not, you're alerted early!). This is the model that is employed for the FSL template.

* Assign to tech (`TECHASSIGN`) - This is the more "classic" assignment model where you give work to a specific field worker. This model is typically used by franchises or any organization where the actual person performing the work is determined by the business. Although the FSL model does not employ this, the template code shows how to get this setup and the code comments explain where this would be the case.

# Playbook: Create Your Own Mapping
Note that besides the integration walkthrough below, we have also provided some other (sometimes simpler) mapping examples under the [additional mapping examples](https://github.com/Nahis/connector-salesforce-mapping-fsl/tree/master/additional%20mapping%20examples/SPOFFER%201/src). If your mapping is simple (the standard use case), then it would probably be a better idea to use that example then the more comprehensive FSL-Dispatch example.

The FSL-Dispatch integration shown in the videos can be applied to any Salesforce configuration. You are going to likely want to map it to some unique Salesforce configuration that you have in your organization in order to take advantage of Dispatch platform features. If you already have a dispatch function within Salesforce that you are satisfied with then you'll likely only utilize the Dispatch mobile product. However if you're working with non-dedicated TPCs then you'll likely be utilizing both the Dispatch Portal and mobile product. To make this a reality all you need to do is change the mapping from the FSL objects and fields included in the template to the objects and fields that you are using in your Salesforce instance.

The mapping exercise consists of the following components:

* Dispatch Triggers - These call the trigger handler
* DispatchTriggerHandler class - this contains all the trigger logic and is called by the Dispatch triggers.
* DispatchTests class - this contains sample tests. At the moment this only provides around 63% coverage. 

It's important to note that this template mapping uses bulkified queries so as to stay well within governor limits. You should make sure your code does the same.

Please also bear in mind that the FSL mapping is probably a bit more complex than your average mapping. For example, the record assignment takes place between the `ServiceAppointment` and `ServiceResource` via an intermediary `ServiceAssignment` record. In most instances, the assignment is directly on the job record. There are other examples but the point is that you'll be needing to adjust your code accordingly to simplify where necessary. We've added comments prefixed with `FSL` in the code to give pointers to these cases.

## Triggers
In general you can deploy the triggers "as is" as there's very little logic in them - just a call to the relevant `DispatchTriggerHandler` method. Although you may want to verify the triggering event to make sure they're sufficient/necessary (i.e. `after insert` and `after update`). 

All the triggers have been prefixed with `Dispatch` but in your instance you can rename them as necessary or include the code snippet into an existing trigger. You will need to create the following triggers (feel free to drop the Dispatch prefix and ensure they are being triggered off the appropriate object):

* Dispatch[YourServiceProvider] - for FSL we named this `DispatchServiceTerritory`
* Dispatch[YourFieldWorker] - for FSL we named this `DispatchServiceResource` 
* Dispatch[YourWorkOrder] - for FSL we named this `DispatchServiceAppointment`
* Dispatch[Note] - for FSL we named this `DispatchNote` (uses standard Notes object)
* DispatchJob - this trigger works off the `dispconn_Job` object so you should be able to leave it as is
 
## Dispatch Trigger Handler methods
This is the most labor intensive exercise but we reckon that this can be completed in a couple of days. Please refer to the comments in the code examples as they should guide you through the process.

Some conventions to note in the Trigger Handler:
* You'll notice variables with an `ext` and `disp` prefix. `ext` prefixed variables point to your core objects whereas the `disp` prefixed variable point to the corresponding `dispconn` objects.
* The linkage from your main object is done by adding a lookup field from the `dispconn` object to your main object. The technical name of this lookup has been prefixed with `Ext` e.g. the `Ext_Service_Provider` lookup on the `dispconn__service_provider` object links to your main object (`ServiceTerritory` in FSL)
 
### `ServiceProviderToDispatch`
This method is responsible for mapping from your "Service Provider" or "Location" object to the `dispconn__Service_Provider` object. Before performing the mapping, it is recommended that you create the following custom fields:

#### On YOUR Service Provider/Location object:

| Suggested Field Label | Field Name | Type | Description | Add to form? |
| ------------- | ------------- | ------------- | ------------- | :--------: |
| Dispatch Me  | Dispatch_Me  | Checkbox | Used to flag service providers that work with Dispatch | Yes |
| Phone  | Phone  | Phone | Service Provider phone. Only add if similar field doesn't already exist | Yes |
| Email  | Email  | Email | Service Provider email. Only add if similar field doesn't already exist | Yes |

#### On the `dispconn__Service_Provider` object:

| Suggested Field Label | Field Name | Type | Description | Add to form? |
| ------------- | ------------- | ------------- | ------------- | :--------: |
| Name of your linked object (Service Territory in FSL) | Ext_Service_Provider | Lookup to your corresponding object (Service Territory in FSL) | Linkage | Yes |

### `TechToDispatch`
**This mapping is only relevant if you are using the `TECHASSIGN` dispatch method. See above for description.**

This method is responsible for mapping from your "Technician" or "Employee" object to the `dispconn__Field_Tech` object. Before performing the mapping, it is recommended that you create the following custom fields:

#### On YOUR Field Worker object:

| Suggested Field Label | Field Name | Type | Description | Add to form? |
| ------------- | ------------- | ------------- | ------------- | :--------: |
| Dispatch Me  | Dispatch_Me  | Checkbox | Used to flag field workers that work with Dispatch | Yes |
| Dispatch Portal Access  | Dispatch_Portal_Access  | Checkbox | Used to flag whether the user can log into the Dispatch Portal (not used for FSL as we can use ResourceType field instead) | Yes |

#### On the `dispconn__Field_Tech` object:

| Suggested Field Label | Field Name | Type | Description | Add to form? |
| ------------- | ------------- | ------------- | ------------- | :--------: |
| Name of your linked object (Service Resource in FSL) | Ext_Tech | Lookup to your corresponding object (Service Resource in FSL) | Linkage | Yes |

### `JobToDispatch`

This method is responsible for mapping from your "Work Order" or "Job" object to the `dispconn__Job` object. This is where all the magic happens! By the way, if you have custom fields, related objects, or notes that you need the field worker to be aware of then you're going to want to include this as markdown in the `description` field - please see the code comments for an example.
Before performing the mapping, it is recommended that you create the following custom fields:

#### On the `dispconn__Job` object:
| Suggested Field Label | Field Name | Type | Description | Add to form? |
| ------------- | ------------- | ------------- | ------------- | :--------: |
| Name of your linked object (Service Appointment in FSL) | Ext_Job | Lookup to your corresponding object (Service Appointment in FSL) | Linkage | Yes |


### `DispatchJobFromDispatch`
**This mapping is only relevant if you wish to consume updates back in Salesforce and show them on your main objects. In general it is recommended.**

This method is responsible for mapping job updates coming back in from Dispatch. Before performing the mapping, it is recommended that you create the following custom fields

#### On YOUR Job/Work Order object:

| Suggested Field Label | Field Name | Type | Description | Add to form? |
| ------------- | ------------- | ------------- | ------------- | :--------: |
| Status  | Dispatch_Status  | Picklist | Used to store the Dispatch status if you can't use a pre-existing field. In FSL, using pre-existing `Status` field | Yes |
| Status Reason | Dispatch_Status_Reason  | Text (20) | Used to store status reasons such as completion reasons. Not used in FSL example | Yes |
| Date Accepted  | Date_Accepted  | DateTime | Used to store date accepted by Service Provider. `Third_Party_Accepted` in FSL | Yes |
| Date Departed  | Date_Departed  | DateTime | Used to store date tech hit "On My Way". Not used in FSL example. | Yes |
| Date Started  | Date_Arrived  | DateTime | Used to store date tech reported "Started". Not used in FSL example. | Yes |
| Date Completed  | Date_Completed  | DateTime | Used to store date tech reported "Completed". Not used in FSL example. | Yes |
| Rating  | Rating  | Integer(2) | Used to store customer rating | Yes |
| Rating Message | Rating_Message  | Long String | Used to store customer rating message | Yes |

Field free to add additional fields to store info sent from the field as you see fit.

### `NoteFromToDispatch`
**This mapping is only relevant if you wish to send notes/attachments back to/from Salesforce and show them against your main objects. In general it is recommended. It is bi-directional but you can choose to make it only go in a single directional by editing the code.**

Note that in the FSL example, there is no `Note` objects against `ServiceAppointment` so we created a custom object called `Service_Appointment_Note` and mapped it to that. That should not be necessary in the standard case i.e. you should be able to do a straight note-to-note mapping.

## Dispatch Test Class
A sample test class has been provided. You will obviously need to update this to cover your use cases.

## Dispatch Retry
It is recommended that you schedule a retry process to make the system more robust. This can be done by executing [these scripts](https://github.com/Nahis/connector-salesforce-mapping-fsl/blob/master/scripts/job_retry.cls)

