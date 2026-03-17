/**
 * Service layer for Atlassian Deal Registration API registration search.
 * Provides typed access to search results and pagination.
 */
public with sharing class AtlassianDealRegApiRegistrations {

    @TestVisible static private AtlassianDealRegApiRegistrations instance;
    @TestVisible static private AtlassianDealRegApiClient client;

    static public AtlassianDealRegApiRegistrations getInstance() {
        if (instance == null) {
            instance = new AtlassianDealRegApiRegistrations();
            client = AtlassianDealRegApiClient.getInstance();
        }
        return instance;
    }

    public static void setApiClient(AtlassianDealRegApiClient apiClient) {
        client = apiClient;
    }

    /**
     * Search registrations for a partner account.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @param status Comma-separated statuses (e.g. DRAFT,SUBMITTED)
     * @param registrationId Filter by specific registration ID
     * @param parentRegistrationId Filter by parent registration ID
     * @param programType Comma-separated program types (DEAL_REGISTRATION,SERVICE_REGISTRATION)
     * @param registrationType PARENT or CHILD
     * @param createdAfter Start date (yyyy-MM-dd); converted to ISO 8601
     * @param createdBefore End date (yyyy-MM-dd); converted to ISO 8601
     * @param pageSize Page size 1-100
     * @param pageToken Pagination token for next page
     * @param sortBy CREATED_AT, LAST_MODIFIED_AT, REGISTRATION_ID, STATUS, PROGRAM_TYPE
     * @param sortOrder ASC or DESC
     * @return SearchRegistrationsResponse with registrations and pagination
     */
    @AuraEnabled(cacheable=false)
    public static SearchRegistrationsResponse searchRegistrationsStatic(
        String partnerAccountId,
        String status,
        String registrationId,
        String parentRegistrationId,
        String programType,
        String registrationType,
        String createdAfter,
        String createdBefore,
        Integer pageSize,
        String pageToken,
        String sortBy,
        String sortOrder
    ) {
        AtlassianDealRegApiRegistrations instance = AtlassianDealRegApiRegistrations.getInstance();
        return instance.searchRegistrations(
            partnerAccountId,
            status,
            registrationId,
            parentRegistrationId,
            programType,
            registrationType,
            createdAfter,
            createdBefore,
            pageSize,
            pageToken,
            sortBy,
            sortOrder
        );
    }

    /**
     * Instance method for search - builds params and calls client.
     */
    public SearchRegistrationsResponse searchRegistrations(
        String partnerAccountId,
        String status,
        String registrationId,
        String parentRegistrationId,
        String programType,
        String registrationType,
        String createdAfter,
        String createdBefore,
        Integer pageSize,
        String pageToken,
        String sortBy,
        String sortOrder
    ) {
        if (String.isBlank(partnerAccountId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('partnerAccountId is required');
        }

        Map<String, String> params = new Map<String, String>();
        if (String.isNotBlank(status)) {
            params.put('status', status);
        }
        if (String.isNotBlank(registrationId)) {
            params.put('registrationId', registrationId);
        }
        if (String.isNotBlank(parentRegistrationId)) {
            params.put('parentRegistrationId', parentRegistrationId);
        }
        if (String.isNotBlank(programType)) {
            params.put('programType', programType);
        }
        if (String.isNotBlank(registrationType)) {
            params.put('registrationType', registrationType);
        }
        if (String.isNotBlank(createdAfter)) {
            params.put('createdAfter', createdAfter + 'T00:00:00Z');
        }
        if (String.isNotBlank(createdBefore)) {
            params.put('createdBefore', createdBefore + 'T23:59:59Z');
        }
        if (pageSize != null && pageSize >= 1 && pageSize <= 100) {
            params.put('limit', String.valueOf(pageSize));
        }
        if (String.isNotBlank(pageToken)) {
            params.put('pageToken', pageToken);
        }
        if (String.isNotBlank(sortBy)) {
            params.put('sortBy', sortBy);
        }
        if (String.isNotBlank(sortOrder)) {
            params.put('sortOrder', sortOrder);
        }

        HttpResponse response = client.searchRegistrations(partnerAccountId, params);
        if (response.getStatusCode() != 200) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException(
                'Search failed: ' + response.getStatus() + ' (' + response.getStatusCode() + ')'
            );
        }
        System.debug('searchRegistrations response:\n' + response.getBody());
        SearchRegistrationsResponse result = (SearchRegistrationsResponse) JSON.deserialize(
            response.getBody(),
            SearchRegistrationsResponse.class
        );
        if (result.registrations == null) {
            result.registrations = new List<RegistrationSearchResult>();
        }
        return result;
    }

    /**
     * Get a single registration (deal or service) by ID.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list
     * @param registrationId Registration ID (e.g. D-xxxx or CD-xxxx)
     * @param programType DEAL_REGISTRATION, SERVICE_REGISTRATION, or human-readable equivalent
     * @return Map of registration fields (from API response)
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getRegistrationStatic(
        String partnerAccountId,
        String registrationId,
        String programType
    ) {
        AtlassianDealRegApiRegistrations instance = AtlassianDealRegApiRegistrations.getInstance();
        return instance.getRegistration(partnerAccountId, registrationId, programType);
    }

    /**
     * Instance method for get registration - calls deals or services endpoint based on programType.
     */
    public Map<String, Object> getRegistration(
        String partnerAccountId,
        String registrationId,
        String programType
    ) {
        if (String.isBlank(partnerAccountId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('partnerAccountId is required');
        }
        if (String.isBlank(registrationId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('registrationId is required');
        }

        String normalized = normalizeProgramType(programType);
        HttpResponse response;
        if (normalized == 'SERVICE_REGISTRATION') {
            response = client.getServiceRegistration(partnerAccountId, registrationId);
        } else {
            response = client.getDealRegistration(partnerAccountId, registrationId);
        }

        if (response.getStatusCode() != 200) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException(
                'Get registration failed: ' + response.getStatus() + ' (' + response.getStatusCode() + ')'
            );
        }

        System.debug('getRegistration response:\n' + response.getBody());

        Object parsed = JSON.deserializeUntyped(response.getBody());
        if (parsed instanceof Map<String, Object>) {
            return (Map<String, Object>) parsed;
        }
        return new Map<String, Object>();
    }

    private static String normalizeProgramType(String value) {
        if (String.isBlank(value)) return '';
        return value.replaceAll('\\s+', '_').toUpperCase();
    }

    private static String parseErrorMessage(HttpResponse response) {
        String body = response.getBody();
        if (String.isNotBlank(body)) {
            try {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
                List<String> parts = new List<String>();
                Object statusCode = parsed.get('statusCode');
                if (statusCode != null) parts.add('Status ' + statusCode);
                Object msg = parsed.get('message');
                if (msg != null) parts.add(String.valueOf(msg));
                Object errors = parsed.get('errors');
                if (errors != null) parts.add('Details: ' + String.valueOf(errors));
                if (!parts.isEmpty()) return String.join(parts, ' — ');
            } catch (Exception e) { }
        }
        return response.getStatus() + ' (' + response.getStatusCode() + ')';
    }

    /**
     * Create a new draft deal registration.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list
     * @param body JSON payload for DealRegistrationPayload
     * @return DraftCreationSuccess with id and status
     */
    @AuraEnabled(cacheable=false)
    public static AtlassianDealRegApiClient.DraftCreationSuccess createDealRegistrationStatic(String partnerAccountId, String body) {
        return AtlassianDealRegApiRegistrations.getInstance().createDealRegistration(partnerAccountId, body);
    }

    public AtlassianDealRegApiClient.DraftCreationSuccess createDealRegistration(String partnerAccountId, String body) {
        if (String.isBlank(partnerAccountId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('partnerAccountId is required');
        }
        if (String.isBlank(body)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('body is required');
        }
        HttpResponse response = client.createDealRegistration(partnerAccountId, body);

        System.debug('createDealRegistration response:\n' + response.getBody());
        
        if (response.getStatusCode() != 201) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('Create deal failed: ' + parseErrorMessage(response));
        }
        return (AtlassianDealRegApiClient.DraftCreationSuccess) JSON.deserialize(response.getBody(), AtlassianDealRegApiClient.DraftCreationSuccess.class);
    }

    /**
     * Create a new draft service registration.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list
     * @param body JSON payload for ServiceRegistrationPayload
     * @return DraftCreationSuccess with id and status
     */
    @AuraEnabled(cacheable=false)
    public static AtlassianDealRegApiClient.DraftCreationSuccess createServiceRegistrationStatic(String partnerAccountId, String body) {
        return AtlassianDealRegApiRegistrations.getInstance().createServiceRegistration(partnerAccountId, body);
    }

    public AtlassianDealRegApiClient.DraftCreationSuccess createServiceRegistration(String partnerAccountId, String body) {
        if (String.isBlank(partnerAccountId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('partnerAccountId is required');
        }
        if (String.isBlank(body)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('body is required');
        }
        
        System.debug('createServiceRegistration body:\n' + body);

        HttpResponse response = client.createServiceRegistration(partnerAccountId, body);
        if (response.getStatusCode() != 201) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('Create service failed: ' + parseErrorMessage(response));
        }
        return (AtlassianDealRegApiClient.DraftCreationSuccess) JSON.deserialize(response.getBody(), AtlassianDealRegApiClient.DraftCreationSuccess.class);
    }

    /**
     * Update an existing deal registration.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list
     * @param registrationId Registration ID (e.g. D-xxxx)
     * @param body JSON payload (partial update)
     */
    @AuraEnabled(cacheable=false)
    public static void updateDealRegistrationStatic(String partnerAccountId, String registrationId, String body) {
        AtlassianDealRegApiRegistrations.getInstance().updateDealRegistration(partnerAccountId, registrationId, body);
    }

    public void updateDealRegistration(String partnerAccountId, String registrationId, String body) {
        if (String.isBlank(partnerAccountId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('partnerAccountId is required');
        }
        if (String.isBlank(registrationId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('registrationId is required');
        }
        if (String.isBlank(body)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('body is required');
        }
        HttpResponse response = client.updateDealRegistration(partnerAccountId, registrationId, body);
        if (response.getStatusCode() != 204) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('Update deal failed: ' + parseErrorMessage(response));
        }
    }

    /**
     * Update an existing service registration.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list
     * @param registrationId Registration ID (e.g. CD-xxxx)
     * @param body JSON payload (partial update)
     */
    @AuraEnabled(cacheable=false)
    public static void updateServiceRegistrationStatic(String partnerAccountId, String registrationId, String body) {
        AtlassianDealRegApiRegistrations.getInstance().updateServiceRegistration(partnerAccountId, registrationId, body);
    }

    public void updateServiceRegistration(String partnerAccountId, String registrationId, String body) {
        if (String.isBlank(partnerAccountId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('partnerAccountId is required');
        }
        if (String.isBlank(registrationId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('registrationId is required');
        }
        if (String.isBlank(body)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('body is required');
        }
        HttpResponse response = client.updateServiceRegistration(partnerAccountId, registrationId, body);
        if (response.getStatusCode() != 204) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('Update service failed: ' + parseErrorMessage(response));
        }
    }

    /**
     * Submit a deal registration for async processing.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list
     * @param registrationId Registration ID (e.g. D-xxxx)
     * @return JobStatusSuccess with jobId and status
     */
    @AuraEnabled(cacheable=false)
    public static JobStatusSuccess submitDealRegistrationStatic(String partnerAccountId, String registrationId) {
        return AtlassianDealRegApiRegistrations.getInstance().submitDealRegistration(partnerAccountId, registrationId);
    }

    public JobStatusSuccess submitDealRegistration(String partnerAccountId, String registrationId) {
        if (String.isBlank(partnerAccountId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('partnerAccountId is required');
        }
        if (String.isBlank(registrationId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('registrationId is required');
        }
        HttpResponse response = client.submitDealRegistration(partnerAccountId, registrationId);
        if (response.getStatusCode() != 202) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('Submit deal failed: ' + parseErrorMessage(response));
        }
        return (JobStatusSuccess) JSON.deserialize(response.getBody(), JobStatusSuccess.class);
    }

    /**
     * Submit a service registration for async processing.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list
     * @param registrationId Registration ID (e.g. CD-xxxx)
     * @return JobStatusSuccess with jobId and status
     */
    @AuraEnabled(cacheable=false)
    public static JobStatusSuccess submitServiceRegistrationStatic(String partnerAccountId, String registrationId) {
        return AtlassianDealRegApiRegistrations.getInstance().submitServiceRegistration(partnerAccountId, registrationId);
    }

    public JobStatusSuccess submitServiceRegistration(String partnerAccountId, String registrationId) {
        if (String.isBlank(partnerAccountId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('partnerAccountId is required');
        }
        if (String.isBlank(registrationId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('registrationId is required');
        }
        HttpResponse response = client.submitServiceRegistration(partnerAccountId, registrationId);
        if (response.getStatusCode() != 202) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('Submit service failed: ' + parseErrorMessage(response));
        }
        return (JobStatusSuccess) JSON.deserialize(response.getBody(), JobStatusSuccess.class);
    }

    /**
     * Get async job status for a submission.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list
     * @param jobId Job ID from submit response
     * @return JobStatusSuccess with job status
     */
    @AuraEnabled(cacheable=false)
    public static JobStatusSuccess getJobStatusStatic(String partnerAccountId, String jobId) {
        return AtlassianDealRegApiRegistrations.getInstance().getJobStatus(partnerAccountId, jobId);
    }

    public JobStatusSuccess getJobStatus(String partnerAccountId, String jobId) {
        if (String.isBlank(partnerAccountId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('partnerAccountId is required');
        }
        if (String.isBlank(jobId)) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('jobId is required');
        }
        HttpResponse response = client.getJobStatus(partnerAccountId, jobId);
        if (response.getStatusCode() != 200) {
            throw new AtlassianDealRegApiClient.AtlassianDealRegApiException('Get job status failed: ' + parseErrorMessage(response));
        }
        return (JobStatusSuccess) JSON.deserialize(response.getBody(), JobStatusSuccess.class);
    }

    // ==================
    //  WRAPPER CLASSES
    // ==================

    public class JobStatusSuccess {
        @AuraEnabled public String jobId;
        @AuraEnabled public String status;
        @AuraEnabled public String createdAt;
        @AuraEnabled public String lastModifiedAt;
        @AuraEnabled public String registrationId;
        @AuraEnabled public Object error;
    }

    public class SearchRegistrationsResponse {
        @AuraEnabled public List<RegistrationSearchResult> registrations;
        @AuraEnabled public Pagination pagination;
    }

    public class RegistrationSearchResult {
        @AuraEnabled public String id;
        @AuraEnabled public String parentRegistrationId;
        @AuraEnabled public String dealName;
        @AuraEnabled public String programType;
        @AuraEnabled public String status;
        @AuraEnabled public String customerContactEmailId;
        @AuraEnabled public String customerDomain;
        @AuraEnabled public String partnerSalesRepresentativeEmailId;
        @AuraEnabled public String partnerSubmittedOpportunityNumber;
        @AuraEnabled public String opportunityNumber;
        @AuraEnabled public String estimatedRevenue;
        @AuraEnabled public String extensionStatus;
        @AuraEnabled public String expirationDate;
        @AuraEnabled public String submissionDate;
        @AuraEnabled public String approvalDate;
        @AuraEnabled public String createdAt;
        @AuraEnabled public String lastModifiedAt;
    }

    public class Pagination {
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public String nextPageToken;
        @AuraEnabled public Boolean hasNext;
        @AuraEnabled public Boolean hasPrevious;
        @AuraEnabled public PaginationLinks links;
    }

    public class PaginationLinks {
        @AuraEnabled public String self;
        @AuraEnabled public String next;
    }
}
