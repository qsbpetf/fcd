/**
 * Controller for creating and editing Atlassian deal registration drafts
 * via the AtlassianRegSubmission__c custom object.
 */
public with sharing class AtlassianDealRegDraftController {

    private static final String PROGRAM_DEAL = 'DEAL_REGISTRATION';
    private static final String PROGRAM_SERVICE = 'SERVICE_REGISTRATION';

    /**
     * Create a submission row only: store JSON locally, no Atlassian API call.
     */
    @AuraEnabled
    public static Map<String, Object> createLocalDealDraft(String partnerAccountId, String body) {
        validateDraftPayload(body);
        String dealName = parseDealName(body);
        if (String.isBlank(dealName)) {
            throw new AuraHandledException('dealName is required in the draft payload');
        }
        if (String.isBlank(partnerAccountId)) {
            throw new AuraHandledException('partnerAccountId is required');
        }

        AtlassianRegSubmission__c sub = new AtlassianRegSubmission__c(
            Name = truncateToNameField(dealName),
            Deal_Name__c = dealName.length() > 255 ? dealName.substring(0, 255) : dealName,
            Draft_Payload_JSON__c = body,
            Program_Type__c = PROGRAM_DEAL,
            Partner_Account_Id__c = partnerAccountId
        );
        insert sub;

        return new Map<String, Object>{
            'recordId' => sub.Id,
            'registrationId' => null,
            'status' => sub.Status__c
        };
    }

    /**
     * Save draft JSON to Salesforce; if a remote registration exists, PATCH the API as well.
     */
    @AuraEnabled
    public static void saveDraftPayload(Id recordId, String body) {
        validateDraftPayload(body);
        String dealName = parseDealName(body);

        AtlassianRegSubmission__c sub = [
            SELECT Id, Registration_Id__c, Partner_Account_Id__c, Program_Type__c
            FROM AtlassianRegSubmission__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        sub.Draft_Payload_JSON__c = body;
        if (String.isNotBlank(dealName)) {
            sub.Deal_Name__c = dealName.length() > 255 ? dealName.substring(0, 255) : dealName;
            sub.Name = truncateToNameField(dealName);
        }

        if (String.isNotBlank(sub.Registration_Id__c)) {
            if (PROGRAM_SERVICE.equalsIgnoreCase(sub.Program_Type__c)) {
                AtlassianDealRegApiRegistrations.getInstance().updateServiceRegistration(
                    sub.Partner_Account_Id__c,
                    sub.Registration_Id__c,
                    body
                );
            } else {
                AtlassianDealRegApiRegistrations.getInstance().updateDealRegistration(
                    sub.Partner_Account_Id__c,
                    sub.Registration_Id__c,
                    body
                );
            }
        }

        update sub;
    }

    /**
     * Create remote Atlassian draft from stored JSON; updates Registration_Id__c and status.
     */
    @AuraEnabled
    public static Map<String, Object> syncDraftToAtlassian(Id recordId) {
        AtlassianRegSubmission__c sub = [
            SELECT
                Id,
                Draft_Payload_JSON__c,
                Partner_Account_Id__c,
                Program_Type__c,
                Registration_Id__c
            FROM AtlassianRegSubmission__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (String.isNotBlank(sub.Registration_Id__c)) {
            throw new AuraHandledException('This submission already has a registration in Atlassian');
        }
        if (String.isBlank(sub.Draft_Payload_JSON__c)) {
            throw new AuraHandledException('No draft payload to sync. Save the form first.');
        }
        if (String.isBlank(sub.Partner_Account_Id__c)) {
            throw new AuraHandledException('Partner Account Id is required');
        }

        AtlassianDealRegApiClient.DraftCreationSuccess result;
        if (PROGRAM_SERVICE.equalsIgnoreCase(sub.Program_Type__c)) {
            result = AtlassianDealRegApiRegistrations.createServiceRegistrationStatic(
                sub.Partner_Account_Id__c,
                sub.Draft_Payload_JSON__c
            );
        } else {
            result = AtlassianDealRegApiRegistrations.createDealRegistrationStatic(
                sub.Partner_Account_Id__c,
                sub.Draft_Payload_JSON__c
            );
        }

        sub.Registration_Id__c = result.id;
        sub.Status__c = result.status;
        sub.Name = 'Draft ' + result.id;
        update sub;

        return new Map<String, Object>{
            'recordId' => sub.Id,
            'registrationId' => result.id,
            'status' => result.status
        };
    }

    private static void validateDraftPayload(String body) {
        if (String.isBlank(body)) {
            throw new AuraHandledException('Draft payload is required');
        }
        try {
            JSON.deserializeUntyped(body);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid JSON payload');
        }
    }

    private static String parseDealName(String body) {
        try {
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(body);
            Object dn = m.get('dealName');
            return dn != null ? String.valueOf(dn).trim() : null;
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Submission Name max 80 in standard Salesforce; keep local names short.
     */
    private static String truncateToNameField(String dealName) {
        if (String.isBlank(dealName)) {
            return 'Atlassian registration';
        }
        return dealName.length() > 80 ? dealName.substring(0, 80) : dealName;
    }

    /**
     * Create a new deal draft via API and persist to AtlassianRegSubmission__c.
     *
     * @param partnerAccountId Partner account ID from partner-accounts/v1/list
     * @param body JSON payload for DealRegistrationPayload
     * @return Map with recordId of the created AtlassianRegSubmission__c
     */
    @AuraEnabled
    public static Map<String, Object> createDealDraft(String partnerAccountId, String body) {
        AtlassianDealRegApiClient.DraftCreationSuccess result = AtlassianDealRegApiRegistrations.createDealRegistrationStatic(partnerAccountId, body);

        AtlassianRegSubmission__c sub = new AtlassianRegSubmission__c(
            Name = 'Draft ' + result.id,
            Registration_Id__c = result.id,
            Status__c = result.status,
            Program_Type__c = PROGRAM_DEAL,
            Partner_Account_Id__c = partnerAccountId,
            Draft_Payload_JSON__c = body,
            Deal_Name__c = parseDealName(body)
        );
        if (sub.Deal_Name__c != null && sub.Deal_Name__c.length() > 255) {
            sub.Deal_Name__c = sub.Deal_Name__c.substring(0, 255);
        }
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
     * @param recordId AtlassianRegSubmission__c record Id
     * @param body JSON payload (partial update)
     */
    @AuraEnabled
    public static void updateDealDraft(Id recordId, String body) {
        AtlassianRegSubmission__c sub = [
            SELECT Id, Registration_Id__c, Partner_Account_Id__c
            FROM AtlassianRegSubmission__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        AtlassianDealRegApiRegistrations.getInstance().updateDealRegistration(
            sub.Partner_Account_Id__c,
            sub.Registration_Id__c,
            body
        );
        sub.Draft_Payload_JSON__c = body;
        String dealName = parseDealName(body);
        if (String.isNotBlank(dealName)) {
            sub.Deal_Name__c = dealName.length() > 255 ? dealName.substring(0, 255) : dealName;
            sub.Name = truncateToNameField(dealName);
        }
        update sub;
    }

    /**
     * Update a deal registration via API by registration ID (no SF record required).
     * Used when editing from search results where the registration may not have
     * an AtlassianRegSubmission__c record.
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
     * Find AtlassianRegSubmission__c by registration ID and partner account.
     * Returns record Id if found, null otherwise.
     *
     * @param partnerAccountId Partner account ID
     * @param registrationId Registration ID (e.g. D-xxxx)
     * @return Map with recordId if found, or empty
     */
    @AuraEnabled
    public static Map<String, Object> findSubmissionByRegistrationId(String partnerAccountId, String registrationId) {
        List<AtlassianRegSubmission__c> subs = [
            SELECT Id, Status__c, Job_Id__c
            FROM AtlassianRegSubmission__c
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
     * @param recordId AtlassianRegSubmission__c record Id
     * @return Map with jobId and status
     */
    @AuraEnabled
    public static Map<String, Object> submitDealDraft(Id recordId) {
        AtlassianRegSubmission__c sub = [
            SELECT Id, Registration_Id__c, Partner_Account_Id__c
            FROM AtlassianRegSubmission__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (String.isBlank(sub.Registration_Id__c)) {
            throw new AuraHandledException('Create the draft in Atlassian before submitting');
        }

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
     * @param recordId AtlassianRegSubmission__c record Id
     * @return Map with Registration_Id__c, Partner_Account_Id__c, Status__c, Job_Id__c
     */
    @AuraEnabled
    public static Map<String, Object> getSubmissionRecord(Id recordId) {
        AtlassianRegSubmission__c sub = [
            SELECT
                Id,
                Registration_Id__c,
                Partner_Account_Id__c,
                Status__c,
                Job_Id__c,
                Program_Type__c,
                Draft_Payload_JSON__c,
                Deal_Name__c
            FROM AtlassianRegSubmission__c
            WHERE Id = :recordId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        Map<String, Object> result = new Map<String, Object>();
        result.put('Registration_Id__c', sub.Registration_Id__c);
        result.put('Partner_Account_Id__c', sub.Partner_Account_Id__c);
        result.put('Status__c', sub.Status__c);
        result.put('Job_Id__c', sub.Job_Id__c);
        result.put('Program_Type__c', sub.Program_Type__c);
        result.put('Draft_Payload_JSON__c', sub.Draft_Payload_JSON__c);
        result.put('Deal_Name__c', sub.Deal_Name__c);
        return result;
    }

    /**
     * Poll job status and update the record.
     *
     * @param recordId AtlassianRegSubmission__c record Id
     * @return Map with status, error (if any)
     */
    @AuraEnabled
    public static Map<String, Object> pollJobStatus(Id recordId) {
        AtlassianRegSubmission__c sub = [
            SELECT Id, Job_Id__c, Partner_Account_Id__c
            FROM AtlassianRegSubmission__c
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