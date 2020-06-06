/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* OpportunityTriggerHandler Handler for Cstom OpportunityTrigger.
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Jaya Alaparthi
* @maintainedBy   Jaya Alaparthi
* @version        1.0
* @created        2019-11-15
* @modified       
* @systemLayer    Service
* @see            ????
* @see            ????
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @changes
* vX.X            Jaya Alaparthi
* YYYY-MM-DD   
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* vX.X            Swathy
* 2019-11-22    
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* v1.2             Jaya Alaparthi
* Modified purpose: Opportunty bill to sold to address updated from contact and to contract
* 2020-01-24
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* v1.3             Jaya Alaparthi
* Modified purpose: payment terms from account to Opportunity
* 2020-01-29
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* v1.4             Jaya Alaparthi
* Modified purpose: stamp opportunity role based on opportunity owner
* 2020-01-29
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
* v1.5            Swathy
* Modified purpose: stamp Billing Batch
* 2020-04-27
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
* v1.6            Dmitry Goshko
* Modified purpose: Recalculate BusinessLineSummaries with related Opportunity on Delete
* 2020-05-05
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
* v1.7            Charles Mutsu
* Modified purpose: Stamp User Type, User Region and User Sub-Region based on opportunity owner
* 2020-05-28
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public without sharing class OpportunityTriggerHandler {
    
    public static String CLOSEDLOST = 'Closed Lost';

    public static void afterUpdate(Map<Id,Opportunity> oldMap, Map<Id,Opportunity> newMap) {        

        // v1.6
        // Update Business Line Summary based on new Opportunity
        if(RecalculateBusinessLineSummaryBatch.doRecalculateBLS) {
            BusinessLineSummaryService.calculateBusinessLineSummary(newMap);
            RecalculateBusinessLineSummaryBatch.doRecalculateBLS = false;
        }

        //Approval rejection on Opportunity closed Lost
        OpportunityHandlerHelper helper = new OpportunityHandlerHelper();
        OpportunityUtil utilRef = new OpportunityUtil();
        Set<Id> qualifiedOpptyIdsSet = new Set<Id>();
        Set<Id> oldContractIdsSet = new Set<Id>();
        List<Opportunity> newOpportunityList = new List<Opportunity>();
        // Oppty record type
        Id coreSalesRTId = utilRef.getOpptyRecordType('Core Sales');
        System.debug('coreSalesRTId:'+coreSalesRTId);
        for(Opportunity oppty: newMap.values()) {
            
            
            if(oldMap.containsKey(oppty.Id)) {
                
                Opportunity oldOppty = new Opportunity();
                oldOppty = oldMap.get(oppty.Id);
                
                System.debug('coreSalesRTId:'+coreSalesRTId+
                    'new OpptyStageName:'+oppty.StageName+
                    'oldOpptyStageName:'+oppty.StageName);
                if(oppty.StageName.equalsIgnoreCase(CLOSEDLOST) 
                    && !oldOppty.StageName.equalsIgnoreCase(CLOSEDLOST)
                    && coreSalesRTId == oppty.RecordTypeId) {
                    qualifiedOpptyIdsSet.add(oppty.Id);
                }
                
               //Swathy Nov 20 - Check for type Amnedment and PO Number blank - start
               if(oppty.RecordTypeId == coreSalesRTId && 
                       oppty.Type == OpportunityUtil.OPP_TYPE_AMENDMENT &&
                       (oldOppty.StageName != oppty.StageName ||
                       oldOppty.PO_Number__c != oppty.PO_Number__c ||
                       oppty.SBQQ__AmendedContract__c != oldOppty.SBQQ__AmendedContract__c) &&
                       oppty.StageName == OpportunityUtil.OPP_STAGE_CLOSEDWON &&
                       String.isNotBlank(oppty.SBQQ__AmendedContract__c) &&
                       String.isNotBlank(oppty.PO_Number__c)) {
               
                   newOpportunityList.add(oppty);
                   if(oppty.SBQQ__AmendedContract__c != oldOppty.SBQQ__AmendedContract__c &&
                      oldOppty.SBQQ__AmendedContract__c != null) {
                     oldContractIdsSet.add(oldOppty.SBQQ__AmendedContract__c);
                   }
                } //end
            }  
                      
        }
        // call for helper for updating approvals
        if(!qualifiedOpptyIdsSet.isEmpty()) {
            helper.rejectPendingApprovals(qualifiedOpptyIdsSet);
        }       
       // end of Approval rejection on closed lost
       
        //Method to update Contract PO number - start
        if(!newOpportunityList.isEmpty()) {
            helper.updateContractPO(newOpportunityList, oldContractIdsSet);
        }//end


    }
    
    public static void afterInsert(Map<Id,Opportunity> newMap) {  

        //Approval rejection on Opportunity closed Lost
        OpportunityHandlerHelper helper = new OpportunityHandlerHelper();
        OpportunityUtil utilRef = new OpportunityUtil();
        List<Opportunity> newOpportunityList = new List<Opportunity>();
        // Oppty record type
        Id coreSalesRTId = utilRef.getOpptyRecordType('Core Sales');
        for(Opportunity oppty: newMap.values()) {
               
           //Swathy Nov 20 - Check for type Amnedment and PO Number blank - start
           if(oppty.RecordTypeId == coreSalesRTId && 
                 oppty.Type == OpportunityUtil.OPP_TYPE_AMENDMENT &&
                 oppty.StageName == OpportunityUtil.OPP_STAGE_CLOSEDWON &&
                 String.isNotBlank(oppty.SBQQ__AmendedContract__c) &&
                 String.isNotBlank(oppty.PO_Number__c)) {
               
                   newOpportunityList.add(oppty);
            } //end  
           
        }
        
        //Method to update Contract PO number - start
        if(!newOpportunityList.isEmpty()) {
            helper.updateContractPO(newOpportunityList, new Set<Id>());
        }//end       

    }
    //v1.2
    public static void beforeUpdate(Map<Id,Opportunity> oldMap, List<Opportunity> newList) {

        Set<Id> contactId  = new Set<Id>();
        Map<Id,Contact> contactMap = new Map<Id,Contact>();
        Map<Id,Opportunity> validatedOpprtunityMap = new Map<Id,Opportunity>();
        Set<Id> ownerIdsSet = new Set<Id>();
        Map<Id,User> userMap = new Map<Id,User>();
        OpportunityHandlerHelper helper = new OpportunityHandlerHelper();
        OpportunityAddressRollut ref = new OpportunityAddressRollut();
        OpportunityUtil utilRef = new OpportunityUtil();
        Id coreSalesRTId = utilRef.getOpptyRecordType('Core Sales');
        System.debug('coreSalesRTId:'+coreSalesRTId);
        boolean excludeWorkdflows = false;
        if(OverrideRules__c.getInstance(UserInfo.getUserId()) != null && 
          OverrideRules__c.getInstance(UserInfo.getUserId()).OverrideWorkflows__c) {
          excludeWorkdflows = true;
        }
        
        for(Opportunity oppty: newList) {
            Opportunity oldOppty;
            //v1.2
            // get sold to and bill to contact ids.
            // core sales
            if(oppty.RecordTypeId == coreSalesRTId) {
            
                //Method call to Update billing batch - CRM-1129
                if(!excludeWorkdflows)
                   helper.updateBillingBatch(oppty);
                if(!oldMap.isEmpty() && oldMap.containsKey(oppty.Id)) {
                    oldOppty = oldMap.get(oppty.Id);
                    if(oppty.Sold_To_Contact__c != null && oppty.Soldto_address_same_as_contact__c) {
                        // copy address to respective fields
                        //oldOppty.Sold_To_Contact__c != oppty.Sold_To_Contact__c 
                        contactId.add(oppty.Sold_To_Contact__c);
                        validatedOpprtunityMap.put(oppty.Id,oppty);
                    }
                    if(oppty.Bill_To_Contact__c != null && oppty.Billing_address_same_as_contact__c) {
                        //oldOppty.Bill_To_Contact__c != oppty.Bill_To_Contact__c 
                        contactId.add(oppty.Bill_To_Contact__c);
                        validatedOpprtunityMap.put(oppty.Id,oppty);
                    }
                    // v1.4 get oppty owner Ids v1.6 check open opptys'
                    if(oppty.OwnerId != null && oldOppty.ownerId != oppty.OwnerId && !oppty.IsClosed) {
                        ownerIdsSet.add(oppty.OwnerId);
                    }

                }
            }
            
        }
        //v1.2
        // update opportunity address from contact when respective flags are checked.
        if(!contactId.isEmpty()) {
            contactMap = ref.getRelatedContacts(contactId);
        }   
        // v1.4
        if(!ownerIdsSet.isEmpty()) {
            userMap = OpportunityUtil.getUserRoles(ownerIdsSet);
        }
        for (Opportunity oppty: newList) {
            
            if(oppty.RecordTypeId == coreSalesRTId && oppty.Soldto_address_same_as_contact__c 
                && oppty.Sold_To_Contact__c != null) {
                Contact cnt;
                if(!contactMap.isEmpty() && contactMap.containsKey(oppty.Sold_To_Contact__c)) {
                    cnt = contactMap.get(oppty.Sold_To_Contact__c);
                    oppty = ref.addressUpdate(oppty, cnt, ref.SOLD_TO);        
                }
            }
            if(oppty.RecordTypeId == coreSalesRTId && oppty.Billing_address_same_as_contact__c 
                && oppty.Bill_To_Contact__c != null) {
                Contact cnt;
                if(!contactMap.isEmpty() && contactMap.containsKey(oppty.Bill_To_Contact__c)) {
                    cnt = contactMap.get(oppty.Bill_To_Contact__c);
                    oppty = ref.addressUpdate(oppty, cnt, ref.BILL_TO); 
                }
            }
            // assign role name v1.6 map user fields CRM-1990
            if(!userMap.isEmpty() && userMap.containsKey(oppty.ownerId)) {
                oppty.Opportunity_Role__c = userMap.get(oppty.ownerId).UserRole.Name;
                oppty.User_Type__c = userMap.get(oppty.ownerId).User_Type__c;
                oppty.Region__c = userMap.get(oppty.ownerId).Region__c;
                oppty.Sub_Region__c = userMap.get(oppty.ownerId).Sub_Region__c;            
            }
        }// end of for
        
    }
    
    // v1.6
    public static void beforeDelete(Map<Id,Opportunity> oldMap) {
        //Update Business Line Summary based on deleted Opportunity
        if(RecalculateBusinessLineSummaryBatch.doRecalculateBLS) {
            BusinessLineSummaryService.calculateBusinessLineSummary(oldMap);
            RecalculateBusinessLineSummaryBatch.doRecalculateBLS = false;
        }
    }
    
    public static void beforeInsert(List<Opportunity> opptyList) {

        Map<Id,Contact> contactMap = new Map<Id,Contact>();
        Map<Id,Account> accountsMap = new Map<Id,Account>();
        Set<Id> contactIds = new Set<Id>();
        Set<Id> accountIdsSet = new Set<Id>();
        Set<Id> ownerIdsSet = new Set<Id>();
        Map<Id,User> userMap = new Map<Id,User>();
        OpportunityHandlerHelper helper = new OpportunityHandlerHelper();
        OpportunityAddressRollut opptyAddRef = new OpportunityAddressRollut();
        OpportunityUtil utilRef = new OpportunityUtil();
        Id coreSalesRTId = utilRef.getOpptyRecordType('Core Sales');
        System.debug('coreSalesRTId:'+coreSalesRTId);
        boolean excludeWorkdflows = false;
        if(OverrideRules__c.getInstance(UserInfo.getUserId()) != null && 
          OverrideRules__c.getInstance(UserInfo.getUserId()).OverrideWorkflows__c) {
          excludeWorkdflows = true;
        }
        //v1.2

        for(Opportunity oppty: opptyList) {
            if(oppty.RecordTypeId == coreSalesRTId) {
                //Method call to Update billing batch - CRM-1129
                if(!excludeWorkdflows)
                    helper.updateBillingBatch(oppty);
                if(oppty.Soldto_address_same_as_contact__c 
                    && oppty.Sold_To_Contact__c != null) {
                contactIds.add(oppty.Sold_To_Contact__c);
                }
                if(oppty.Billing_address_same_as_contact__c 
                    && oppty.Bill_To_Contact__c != null) {
                    contactIds.add(oppty.Bill_To_Contact__c);
                }
                //v1.3
                // get account ids
                if(oppty.AccountId != null) {
                    accountIdsSet.add(oppty.AccountId);                 
                }
                // v1.4 get oppty owner Ids
                if(oppty.OwnerId != null) {
                    ownerIdsSet.add(oppty.OwnerId);
                }
            }
        
        }

        // v1.2
        if(!contactIds.isEmpty()) {
            contactMap = opptyAddRef.getRelatedContacts(contactIds);
        }      
        // v1.3  
        if(!accountIdsSet.isEmpty()) {
            accountsMap =  OpportunityUtil.getAccounts(accountIdsSet);
        }
        // v1.4
        if(!ownerIdsSet.isEmpty()) {
            userMap = OpportunityUtil.getUserRoles(ownerIdsSet);
        }
        
        
        for(Opportunity oppty: opptyList) {
            // assign address to oppty address fields
            // core sales
            if(oppty.RecordTypeId == coreSalesRTId) {
                if(oppty.Soldto_address_same_as_contact__c 
                    && oppty.Sold_To_Contact__c != null) {
                    Contact cnt;
                    if(!contactMap.isEmpty() && contactMap.containsKey(oppty.Sold_To_Contact__c)) {
                        cnt = contactMap.get(oppty.Sold_To_Contact__c);
                        oppty = opptyAddRef.addressUpdate(oppty, cnt, opptyAddRef.SOLD_TO);        
                    }
                }
                if(oppty.Billing_address_same_as_contact__c 
                    && oppty.Bill_To_Contact__c != null) {
                    Contact cnt;
                    if(!contactMap.isEmpty() && contactMap.containsKey(oppty.Bill_To_Contact__c)) {
                        cnt = contactMap.get(oppty.Bill_To_Contact__c);
                        oppty = opptyAddRef.addressUpdate(oppty, cnt, opptyAddRef.BILL_TO); 
                    }
                }
                // assign payment terms
                if(!accountsMap.isEmpty() && oppty.AccountId != null && accountsMap.containsKey(oppty.AccountId)) {
                    oppty.Payment_Terms__c = accountsMap.get(oppty.AccountId).Payment_Terms__c;
                } else {
                    oppty.Payment_Terms__c = OpportunityUtil.OPPTY_PAY_TERM_30;
                }
                // assign role name v1.6 map user fields CRM-1990
                if(!userMap.isEmpty() && userMap.containsKey(oppty.ownerId)) {
                    oppty.Opportunity_Role__c = userMap.get(oppty.ownerId).UserRole.Name;
                    oppty.User_Type__c = userMap.get(oppty.ownerId).User_Type__c;
                    oppty.Region__c = userMap.get(oppty.ownerId).Region__c;
                    oppty.Sub_Region__c = userMap.get(oppty.ownerId).Sub_Region__c;
                }
            }
        }
    }
}