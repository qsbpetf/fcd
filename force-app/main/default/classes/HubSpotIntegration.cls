public with sharing class HubSpotIntegration {
    private static final Integer HTTP_REQUEST_TIMEOUT = 10000; // 10 seconds
    private static final String NAMED_CREDENTIAL = 'HubSpot';
    private static final Integer ASSOCIATION_CHILD_TO_PARENT_COMPANY = 14;

    private List<FlowRequest> flowRequests;

    // This method is called from flow to process account records
    @InvocableMethod(label='HubSpot: Update account hierarchy' description='Updates Salesforce account hierarchy changes to HubSpot.' category='HubSpot' callout=true)
    public static List<FlowResponse> processAccountHierarchyUpdates(List<FlowRequest> flowRequests) {
        Logger.debug('Update account hierarchy in HubSpot - amount of accounts to process: ' + flowRequests.size());
        Logger.saveLog();

        HubSpotIntegration hsi = new HubSpotIntegration(flowRequests);
        return hsi.updateAccountHierarchy();
    }

    public HubSpotIntegration(List<FlowRequest> flowRequests) {
        this.flowRequests = flowRequests;
    }

    public List<FlowResponse> updateAccountHierarchy() {
        List<FlowResponse> flowResponses = new List<FlowResponse>();

        Map<Id, Account> parentAccounts = getParentAccounts(flowRequests);
        Map<Id, Account> oldParentAccounts = getOldParentAccounts(flowRequests);

        Map<Id, Account> updateMap = new Map<Id, Account>();
        for (FlowRequest fReq : flowRequests) {
            Account currentAccount = fReq.acc;
            Account oldParentAccount = String.isNotBlank(fReq.oldParentId) ? oldParentAccounts.get(fReq.oldParentId) : null;
            Account parentAccount = currentAccount.ParentId != null ? parentAccounts.get(currentAccount.ParentId) : null;

            FlowResponse fResp = new FlowResponse();
            fResp.status = 'ERROR';
            fResp.accountId = currentAccount.Id;
            flowResponses.add(fResp);

            if (currentAccount.HS_Object_ID__c == null) {
                fResp.status = 'NO_HSID';
                Logger.warn('Child account HS_Object_ID__c field is empty, cannot send hierarchy information without HubSpot id', currentAccount);
                continue;
            }

            try {
                Boolean removeStatus = sendRemoveAssociation(currentAccount, oldParentAccount, updateMap);
                Boolean addStatus = sendAddAssociation(currentAccount, parentAccount, updateMap);

                fResp.status = removeStatus && addStatus ? 'OK' : 'ERROR';
            } catch (Exception e) {
                Logger.error(e.getMessage(), currentAccount, e);
                fResp.status = 'ERROR';
            }
        }

        updateAccounts(updateMap.values());

        Logger.saveLog();

        return flowResponses;
    }

    private Map<Id, Account> getParentAccounts(List<FlowRequest> flowRequests) {
        List<Id> parentAccountIds = new List<Id>();

        for (FlowRequest fReq : flowRequests) {
            if (fReq.acc.ParentId != null) {
                parentAccountIds.add(fReq.acc.ParentId);
            }
        }

        return new Map<Id, Account>([SELECT Id, Name, HS_Object_ID__c FROM Account WHERE Id = :parentAccountIds WITH USER_MODE]);
    }

    private Map<Id, Account> getOldParentAccounts(List<FlowRequest> flowRequests) {
        List<String> oldParentAccountIds = new List<String>();

        for (FlowRequest fReq : flowRequests) {
            if (String.isNotBlank(fReq.oldParentId)) {
                oldParentAccountIds.add(fReq.oldParentId);
            }
        }

        return new Map<Id, Account>([SELECT Id, Name, HS_Object_ID__c FROM Account WHERE Id = :oldParentAccountIds WITH USER_MODE]);
    }

    private Boolean sendRemoveAssociation(Account currentAccount, Account oldParentAccount, Map<Id, Account> updateMap) {
        if (oldParentAccount == null) {
            return true;
        }

        if (oldParentAccount.HS_Object_ID__c == null) {
            Logger.warn('Old parent account HS_Object_ID__c field is empty, cannot remove old parent association without HubSpot id', oldParentAccount);
            return false;
        }

        String childId = String.valueOf(currentAccount.HS_Object_ID__c.longValue());
        String parentId = String.valueOf(oldParentAccount.HS_Object_ID__c.longValue());

        String url = '/crm/v4/objects/company/' + childId + '/associations/company/' + parentId;

        Logger.debug('HTTP DELETE ' + url + '\n[remove "' + currentAccount.Name + '" as a child company from "' + oldParentAccount.Name + '" in HubSpot]', currentAccount);

        HttpResponse httpResp = callHubSpot('DELETE', url, null);
        if (httpResp.getStatusCode() > 299) {
            Logger.error(httpResp.getStatusCode() + ': ' + httpResp.getStatus() + '\n' + httpResp.getBody(), currentAccount);
            throw new HubSpotIntegrationException('Failed to remove old parent account from HubSpot');
        }
        currentAccount.HS_Parent_Company_ID__c = null;
        updateMap.put(currentAccount.Id, currentAccount);

        return true;
    }

    private Boolean sendAddAssociation(Account currentAccount, Account parentAccount, Map<Id, Account> updateMap) {
        if (parentAccount == null) {
            return true;
        }

        if (parentAccount.HS_Object_ID__c == null) {
            Logger.warn('Parent account HS_Object_ID__c field is empty, cannot add parent association without HubSpot id', parentAccount);
            return false;
        }

        String childId = String.valueOf(currentAccount.HS_Object_ID__c.longValue());
        String parentId = String.valueOf(parentAccount.HS_Object_ID__c.longValue());

        List<Map<String, Object>> payloadList = new List<Map<String, Object>>();
        Map<String, Object> association = new Map<String, Object>();
        association.put('associationCategory', 'HUBSPOT_DEFINED');
        association.put('associationTypeId', ASSOCIATION_CHILD_TO_PARENT_COMPANY);
        payloadList.add(association);
        String payloadJSON = System.JSON.serializePretty(payloadList, true);

        String url = '/crm/v4/objects/company/' + childId + '/associations/company/' + parentId;

        Logger.debug('HTTP PUT ' + url + '\n[add "' + currentAccount.Name + '" as a child company to "' + parentAccount.Name + '" in HubSpot]', currentAccount);

        HttpResponse httpResp = callHubSpot('PUT', url, payloadJSON);
        if (httpResp.getStatusCode() > 299) {
            Logger.error(httpResp.getStatusCode() + ': ' + httpResp.getStatus() + '\n' + httpResp.getBody(), currentAccount);
            throw new HubSpotIntegrationException('Failed to add new parent account in HubSpot');
        }
        currentAccount.HS_Parent_Company_ID__c = Long.valueOf(parentId);
        updateMap.put(currentAccount.Id, currentAccount);

        return true;
    }

    @TestVisible
    private void updateAccounts(List<Account> updateList) {
        List<Database.SaveResult> saveResults = Database.update(updateList, false, AccessLevel.SYSTEM_MODE);
        for (Database.SaveResult sr : saveResults) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    Logger.error('Account (' + sr.getId() + ') update failed - ' + err.getStatusCode() + ': ' + err.getMessage() + '\n' + err.getFields());
                }
            }
        }
    }

    private HttpResponse callHubSpot(String method, String url, String payload) {
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + url);
        req.setMethod(method);
        req.setTimeout(HTTP_REQUEST_TIMEOUT);
        if (payload != null) {
            req.setBody(payload);
        }

        HttpResponse resp = h.send(req);

        return resp;
    }

    public class FlowRequest {
        @InvocableVariable(label='Old Parent Account Id' required=false)
        public String oldParentId;

        @InvocableVariable(label='Account' required=true)
        public Account acc;
    }

    public class FlowResponse {
        @InvocableVariable(label='Account Id')
        public String accountId;

        @InvocableVariable(label='Status')
        public String status;
    }

    public class HubSpotIntegrationException extends Exception {
    }
}