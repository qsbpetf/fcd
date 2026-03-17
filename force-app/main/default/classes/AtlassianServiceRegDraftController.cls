/**
 * Controller for creating and editing Atlassian service registration drafts
 * via the AtlassianRegSubmission__c custom object.
 */
public with sharing class AtlassianServiceRegDraftController {

    /**
     * Create a new service draft via API and persist to AtlassianRegSubmission__c.
     *
     * @param partnerAccountId Partner account ID from partner-accounts/v1/list
     * @param body JSON payload for ServiceRegistrationPayload
     * @return Map with recordId of the created AtlassianRegSubmission__c
     */
    @AuraEnabled
    public static Map<String, Object> createServiceDraft(String partnerAccountId, String body) {
        AtlassianDealRegApiClient.DraftCreationSuccess result = AtlassianDealRegApiRegistrations.createServiceRegistrationStatic(partnerAccountId, body);

        AtlassianRegSubmission__c sub = new AtlassianRegSubmission__c(
            Name = 'Draft ' + result.id,
            Registration_Id__c = result.id,
            Status__c = result.status,
            Program_Type__c = 'SERVICE_REGISTRATION',
            Partner_Account_Id__c = partnerAccountId
        );
        insert sub;

        return new Map<String, Object>{
            'recordId' => sub.Id,
            'registrationId' => result.id,
            'status' => result.status
        };
    }

    /**
     * Update an existing service draft via API.
     *
     * @param recordId AtlassianRegSubmission__c record Id
     * @param body JSON payload (partial update)
     */
    @AuraEnabled
    public static void updateServiceDraft(Id recordId, String body) {
        AtlassianRegSubmission__c sub = [
            SELECT Id, Registration_Id__c, Partner_Account_Id__c
            FROM AtlassianRegSubmission__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        AtlassianDealRegApiRegistrations.getInstance().updateServiceRegistration(
            sub.Partner_Account_Id__c,
            sub.Registration_Id__c,
            body
        );
    }

    /**
     * Update a service registration via API by registration ID (no SF record required).
     *
     * @param partnerAccountId Partner account ID from partner-accounts/v1/list
     * @param registrationId Registration ID (e.g. CD-xxxx)
     * @param body JSON payload (partial update)
     */
    @AuraEnabled
    public static void updateServiceDraftByRegistrationId(String partnerAccountId, String registrationId, String body) {
        AtlassianDealRegApiRegistrations.getInstance().updateServiceRegistration(
            partnerAccountId,
            registrationId,
            body
        );
    }

    /**
     * Submit a service draft for async processing. Updates the record with jobId and status.
     *
     * @param recordId AtlassianRegSubmission__c record Id
     * @return Map with jobId and status
     */
    @AuraEnabled
    public static Map<String, Object> submitServiceDraft(Id recordId) {
        AtlassianRegSubmission__c sub = [
            SELECT Id, Registration_Id__c, Partner_Account_Id__c
            FROM AtlassianRegSubmission__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        AtlassianDealRegApiRegistrations.JobStatusSuccess result = AtlassianDealRegApiRegistrations.getInstance().submitServiceRegistration(
            sub.Partner_Account_Id__c,
            sub.Registration_Id__c
        );

        sub.Job_Id__c = result.jobId;
        sub.Status__c = result.status;
        sub.Last_Polled__c = Datetime.now();
        sub.Error__c = result.error != null ? String.valueOf(result.error) : null;
        update sub;

        return new Map<String, Object>{
            'jobId' => result.jobId,
            'status' => result.status,
            'registrationId' => result.registrationId
        };
    }
}
