/**
 * Controller for creating and editing Atlassian deal registration drafts
 * via the AtlassianDealRegSubmission__c custom object.
 */
public with sharing class AtlassianDealRegDraftController {

    /**
     * Create a new deal draft via API and persist to AtlassianDealRegSubmission__c.
     *
     * @param partnerAccountId Partner account ID from partner-accounts/v1/list
     * @param body JSON payload for DealRegistrationPayload
     * @return Map with recordId of the created AtlassianDealRegSubmission__c
     */
    @AuraEnabled
    public static Map<String, Object> createDealDraft(String partnerAccountId, String body) {
        AtlassianDealRegApiClient.DraftCreationSuccess result = AtlassianDealRegApiRegistrations.createDealRegistrationStatic(partnerAccountId, body);

        AtlassianDealRegSubmission__c sub = new AtlassianDealRegSubmission__c(
            Name = 'Draft ' + result.id,
            Registration_Id__c = result.id,
            Status__c = result.status,
            Program_Type__c = 'DEAL_REGISTRATION',
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
     * Update an existing deal draft via API.
     *
     * @param recordId AtlassianDealRegSubmission__c record Id
     * @param body JSON payload (partial update)
     */
    @AuraEnabled
    public static void updateDealDraft(Id recordId, String body) {
        AtlassianDealRegSubmission__c sub = [
            SELECT Id, Registration_Id__c, Partner_Account_Id__c
            FROM AtlassianDealRegSubmission__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        AtlassianDealRegApiRegistrations.getInstance().updateDealRegistration(
            sub.Partner_Account_Id__c,
            sub.Registration_Id__c,
            body
        );
    }

    /**
     * Update a deal registration via API by registration ID (no SF record required).
     * Used when editing from search results where the registration may not have
     * an AtlassianDealRegSubmission__c record.
     *
     * @param partnerAccountId Partner account ID from partner-accounts/v1/list
     * @param registrationId Registration ID (e.g. D-xxxx)
     * @param body JSON payload (partial update)
     */
    @AuraEnabled
    public static void updateDealDraftByRegistrationId(String partnerAccountId, String registrationId, String body) {
        AtlassianDealRegApiRegistrations.getInstance().updateDealRegistration(
            partnerAccountId,
            registrationId,
            body
        );
    }

    /**
     * Find AtlassianDealRegSubmission__c by registration ID and partner account.
     * Returns record Id if found, null otherwise.
     *
     * @param partnerAccountId Partner account ID
     * @param registrationId Registration ID (e.g. D-xxxx)
     * @return Map with recordId if found, or empty
     */
    @AuraEnabled
    public static Map<String, Object> findSubmissionByRegistrationId(String partnerAccountId, String registrationId) {
        List<AtlassianDealRegSubmission__c> subs = [
            SELECT Id, Status__c, Job_Id__c
            FROM AtlassianDealRegSubmission__c
            WHERE Registration_Id__c = :registrationId
            AND Partner_Account_Id__c = :partnerAccountId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (subs.isEmpty()) {
            return new Map<String, Object>();
        }
        return new Map<String, Object>{
            'recordId' => subs[0].Id,
            'status' => subs[0].Status__c,
            'jobId' => subs[0].Job_Id__c
        };
    }

    /**
     * Submit a deal draft for async processing. Updates the record with jobId and status.
     *
     * @param recordId AtlassianDealRegSubmission__c record Id
     * @return Map with jobId and status
     */
    @AuraEnabled
    public static Map<String, Object> submitDealDraft(Id recordId) {
        AtlassianDealRegSubmission__c sub = [
            SELECT Id, Registration_Id__c, Partner_Account_Id__c
            FROM AtlassianDealRegSubmission__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        AtlassianDealRegApiRegistrations.JobStatusSuccess result = AtlassianDealRegApiRegistrations.getInstance().submitDealRegistration(
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

    /**
     * Get submission record for edit mode.
     *
     * @param recordId AtlassianDealRegSubmission__c record Id
     * @return Map with Registration_Id__c, Partner_Account_Id__c, Status__c, Job_Id__c
     */
    @AuraEnabled
    public static Map<String, Object> getSubmissionRecord(Id recordId) {
        AtlassianDealRegSubmission__c sub = [
            SELECT Id, Registration_Id__c, Partner_Account_Id__c, Status__c, Job_Id__c
            FROM AtlassianDealRegSubmission__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        Map<String, Object> result = new Map<String, Object>();
        result.put('Registration_Id__c', sub.Registration_Id__c);
        result.put('Partner_Account_Id__c', sub.Partner_Account_Id__c);
        result.put('Status__c', sub.Status__c);
        result.put('Job_Id__c', sub.Job_Id__c);
        return result;
    }

    /**
     * Poll job status and update the record.
     *
     * @param recordId AtlassianDealRegSubmission__c record Id
     * @return Map with status, error (if any)
     */
    @AuraEnabled
    public static Map<String, Object> pollJobStatus(Id recordId) {
        AtlassianDealRegSubmission__c sub = [
            SELECT Id, Job_Id__c, Partner_Account_Id__c
            FROM AtlassianDealRegSubmission__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (String.isBlank(sub.Job_Id__c)) {
            throw new AuraHandledException('No job ID to poll');
        }

        AtlassianDealRegApiRegistrations.JobStatusSuccess result = AtlassianDealRegApiRegistrations.getInstance().getJobStatus(
            sub.Partner_Account_Id__c,
            sub.Job_Id__c
        );

        sub.Status__c = result.status;
        sub.Last_Polled__c = Datetime.now();
        sub.Error__c = result.error != null ? String.valueOf(result.error) : null;
        update sub;

        return new Map<String, Object>{
            'status' => result.status,
            'error' => result.error,
            'lastModifiedAt' => result.lastModifiedAt
        };
    }
}
