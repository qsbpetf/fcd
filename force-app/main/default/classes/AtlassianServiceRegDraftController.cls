/**
 * Controller for creating and editing Atlassian service registration drafts
 * via the AtlassianRegSubmission__c custom object.
 */
public with sharing class AtlassianServiceRegDraftController {

    private static final String PROGRAM_SERVICE = 'SERVICE_REGISTRATION';

    /**
     * Create a submission row only: store JSON locally, no Atlassian API call.
     */
    @AuraEnabled
    public static Map<String, Object> createLocalServiceDraft(String partnerAccountId, String body) {
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
            Program_Type__c = PROGRAM_SERVICE,
            Partner_Account_Id__c = partnerAccountId
        );
        insert sub;

        return new Map<String, Object>{
            'recordId' => sub.Id,
            'registrationId' => null,
            'status' => sub.Status__c
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

    private static String truncateToNameField(String dealName) {
        if (String.isBlank(dealName)) {
            return 'Atlassian registration';
        }
        return dealName.length() > 80 ? dealName.substring(0, 80) : dealName;
    }

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

        String dealName = parseDealName(body);
        AtlassianRegSubmission__c sub = new AtlassianRegSubmission__c(
            Name = 'Draft ' + result.id,
            Registration_Id__c = result.id,
            Status__c = result.status,
            Program_Type__c = PROGRAM_SERVICE,
            Partner_Account_Id__c = partnerAccountId,
            Draft_Payload_JSON__c = body,
            Deal_Name__c = (dealName != null && dealName.length() > 255) ? dealName.substring(0, 255) : dealName
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
        sub.Draft_Payload_JSON__c = body;
        String dealName = parseDealName(body);
        if (String.isNotBlank(dealName)) {
            sub.Deal_Name__c = dealName.length() > 255 ? dealName.substring(0, 255) : dealName;
            sub.Name = truncateToNameField(dealName);
        }
        update sub;
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

        if (String.isBlank(sub.Registration_Id__c)) {
            throw new AuraHandledException('Create the draft in Atlassian before submitting');
        }

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
