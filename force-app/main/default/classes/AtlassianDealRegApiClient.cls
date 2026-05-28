/**
 * The `AtlassianDealRegApiClient` class provides methods to interact with
 * the Atlassian Deal Registration API for partner accounts, deal and service
 * registrations, search, and job status. It follows a singleton pattern and
 * uses the named credential `Atlassian_deal_Reg_API` for authentication.
 */
public with sharing class AtlassianDealRegApiClient {

    public class AtlassianDealRegApiException extends Exception {}

    @TestVisible static private AtlassianDealRegApiClient instance;

    @TestVisible static private final String NAMED_CREDENTIAL = 'Atlassian_deal_Reg_API';
    @TestVisible static private final String BASE_ENDPOINT = 'callout:' + NAMED_CREDENTIAL;
    @TestVisible static private final String PARTNER_ACCOUNTS_LIST = '/partner/partner-accounts/v1/list';
    @TestVisible static private final String DEALS_PATH = '/partner/registrations/v1/deals';
    @TestVisible static private final String SERVICES_PATH = '/partner/registrations/v1/services';
    @TestVisible static private final String SEARCH_PATH = '/partner/registrations/v1/search';
    @TestVisible static private final String JOBS_PATH = '/partner/jobs/v1';

    /**
     * Returns the singleton instance of the AtlassianDealRegApiClient.
     *
     * @return The instance of the AtlassianDealRegApiClient
     */
    static public AtlassianDealRegApiClient getInstance() {
        if (instance == null) {
            instance = new AtlassianDealRegApiClient();
        }
        return instance;
    }

    /**
     * List partner accounts accessible to the authenticated caller.
     *
     * @return HttpResponse with partnerAccounts JSON
     */
    public HttpResponse listPartnerAccounts() {
        HttpRequest req = createRequestHeader(false, null);
        req.setEndpoint(generateEndpoint(PARTNER_ACCOUNTS_LIST, null));
        req.setMethod('GET');
        return new Http().send(req);
    }

    /**
     * Create a new draft deal registration.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @param body JSON payload for DealRegistrationPayload
     * @return HttpResponse with DraftCreationSuccess (201) or ApiResponse (error)
     */
    public HttpResponse createDealRegistration(String partnerAccountId, String body) {
        HttpRequest req = createRequestHeader(true, partnerAccountId);
        req.setEndpoint(generateEndpoint(DEALS_PATH, null));
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('POST');
        req.setBody(body);
        return new Http().send(req);
    }

    /**
     * Create a new draft service registration.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @param body JSON payload for ServiceRegistrationPayload
     * @return HttpResponse with DraftCreationSuccess (201) or ApiResponse (error)
     */
    public HttpResponse createServiceRegistration(String partnerAccountId, String body) {
        HttpRequest req = createRequestHeader(true, partnerAccountId);
        req.setEndpoint(generateEndpoint(SERVICES_PATH, null));
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('POST');
        req.setBody(body);
        return new Http().send(req);
    }

    /**
     * Get a deal registration by ID.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @param registrationId Registration ID (e.g. D-xxxx)
     * @return HttpResponse with DealRegistrationView
     */
    public HttpResponse getDealRegistration(String partnerAccountId, String registrationId) {
        HttpRequest req = createRequestHeader(true, partnerAccountId);
        req.setEndpoint(generateEndpoint(DEALS_PATH + '/' + registrationId, null));
        req.setMethod('GET');
        return new Http().send(req);
    }

    /**
     * Get a service registration by ID.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @param registrationId Registration ID (e.g. CD-xxxx)
     * @return HttpResponse with ServiceRegistrationView
     */
    public HttpResponse getServiceRegistration(String partnerAccountId, String registrationId) {
        HttpRequest req = createRequestHeader(true, partnerAccountId);
        req.setEndpoint(generateEndpoint(SERVICES_PATH + '/' + registrationId, null));
        req.setMethod('GET');
        return new Http().send(req);
    }

    /**
     * Update an existing deal registration.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @param registrationId Registration ID
     * @param body JSON payload (partial update)
     * @return HttpResponse 204 on success
     */
    public HttpResponse updateDealRegistration(String partnerAccountId, String registrationId, String body) {
        HttpRequest req = createRequestHeader(true, partnerAccountId);
        req.setEndpoint(generateEndpoint(DEALS_PATH + '/' + registrationId, null));
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('PATCH');
        req.setBody(body);
        return new Http().send(req);
    }

    /**
     * Update an existing service registration.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @param registrationId Registration ID
     * @param body JSON payload (partial update)
     * @return HttpResponse 204 on success
     */
    public HttpResponse updateServiceRegistration(String partnerAccountId, String registrationId, String body) {
        HttpRequest req = createRequestHeader(true, partnerAccountId);
        req.setEndpoint(generateEndpoint(SERVICES_PATH + '/' + registrationId, null));
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('PATCH');
        req.setBody(body);
        return new Http().send(req);
    }

    /**
     * Submit a deal registration for processing.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @param registrationId Registration ID
     * @return HttpResponse with jobId for async processing
     */
    public HttpResponse submitDealRegistration(String partnerAccountId, String registrationId) {
        HttpRequest req = createRequestHeader(true, partnerAccountId);
        req.setEndpoint(generateEndpoint(DEALS_PATH + '/' + registrationId + '/submit', null));
        req.setMethod('POST');
        return new Http().send(req);
    }

    /**
     * Submit a service registration for processing.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @param registrationId Registration ID
     * @return HttpResponse with jobId for async processing
     */
    public HttpResponse submitServiceRegistration(String partnerAccountId, String registrationId) {
        HttpRequest req = createRequestHeader(true, partnerAccountId);
        req.setEndpoint(generateEndpoint(SERVICES_PATH + '/' + registrationId + '/submit', null));
        req.setMethod('POST');
        return new Http().send(req);
    }

    /**
     * Search registrations for a partner account.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @param params Map of query params: status, registrationId, parentRegistrationId,
     *              programType, registrationType, createdAfter, createdBefore,
     *              limit, pageToken, sortBy, sortOrder
     * @return HttpResponse with SearchRegistrationsResponse
     */
    public HttpResponse searchRegistrations(String partnerAccountId, Map<String, String> params) {
        HttpRequest req = createRequestHeader(true, partnerAccountId);
        req.setEndpoint(generateEndpoint(SEARCH_PATH, params));
        req.setMethod('GET');
        return new Http().send(req);
    }

    /**
     * Get async job status.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @param jobId Job ID from submit response
     * @return HttpResponse with job status
     */
    public HttpResponse getJobStatus(String partnerAccountId, String jobId) {
        HttpRequest req = createRequestHeader(true, partnerAccountId);
        req.setEndpoint(generateEndpoint(JOBS_PATH + '/' + jobId + '/status', null));
        req.setMethod('GET');
        return new Http().send(req);
    }

    /**
     * Request an extension for a deal registration.
     *
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @param registrationId Registration ID
     * @param body JSON payload for ExtensionRequestPayload
     * @return HttpResponse
     */
    public HttpResponse requestDealExtension(String partnerAccountId, String registrationId, String body) {
        HttpRequest req = createRequestHeader(true, partnerAccountId);
        req.setEndpoint(generateEndpoint(DEALS_PATH + '/' + registrationId + '/extensions', null));
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('POST');
        req.setBody(body);
        return new Http().send(req);
    }

    /**
     * Generates the full endpoint URL with optional query parameters.
     *
     * @param path API path (e.g. /partner/partner-accounts/v1/list)
     * @param queryParams Optional map of query parameter name to value
     * @return Full endpoint URL
     */
    @TestVisible
    private String generateEndpoint(String path, Map<String, String> queryParams) {
        String endpoint = BASE_ENDPOINT + path;
        if (queryParams != null && !queryParams.isEmpty()) {
            endpoint += '?';
            for (String key : queryParams.keySet()) {
                String value = queryParams.get(key);
                if (value != null && value != '') {
                    endpoint += key + '=' + EncodingUtil.urlEncode(value, 'UTF-8') + '&';
                }
            }
            endpoint = endpoint.removeEnd('&');
        }
        System.debug('generateEndpoint endpoint:\n' + endpoint);
        return endpoint;
    }

    /**
     * Creates an HttpRequest with standard headers.
     *
     * @param includePartnerAccountId Whether to add X-Partner-Account-Id header
     * @param partnerAccountId partnerId from partner-accounts/v1/list (use PartnerAccount.partnerId)
     * @return HttpRequest
     */
    @TestVisible
    static HttpRequest createRequestHeader(Boolean includePartnerAccountId, String partnerAccountId) {
        HttpRequest req = new HttpRequest();
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);
        if (includePartnerAccountId && String.isNotBlank(partnerAccountId)) {
            req.setHeader('X-Partner-Account-Id', partnerAccountId);
        }
        return req;
    }

    // ==================
    //  RESPONSE WRAPPERS
    // ==================

    public class DraftCreationSuccess {
        @AuraEnabled public String id;
        @AuraEnabled public String status;
    }

    public class ApiResponse {
        @AuraEnabled public Integer statusCode;
        @AuraEnabled public Object data;
        @AuraEnabled public String message;
        @AuraEnabled public Object errors;
    }

    public class SearchRegistrationsResponse {
        @AuraEnabled public List<Object> registrations;
        @AuraEnabled public Object pagination;
    }
}