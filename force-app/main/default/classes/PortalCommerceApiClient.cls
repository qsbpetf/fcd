/**
 * The `PortalCommerceApiClient` class provides methods to interact with
 * the Commerce API for various entities like products, quotes, invoices,
 * and invoice groups. It follows a singleton pattern to ensure a single
 * instance and uses named credentials to authenticate and access the API.
 */

public with sharing class PortalCommerceApiClient {

    public class PortalCommerceApiException extends Exception {}

    @TestVisible static private PortalCommerceApiClient instance;

    @TestVisible static private final String COMMERCE_API = 'callout:{{NAMED_CREDENTIAL}}/commerce/api';
    @TestVisible static private final String PRODUCTS_ENDPOINT = '/v2/products';
    @TestVisible static private final String QUOTES_ENDPOINT = '/v1/quotes';
    @TestVisible static private final String QUOTE_ENDPOINT = '/v2/quotes';
    @TestVisible static private final String QUOTE_PDF_ENDPOINT = '/v3/quotes/{{QUOTE_ID}}/download';
    @TestVisible static private final String INVOICES_ENDPOINT = '/v2/invoices';
    @TestVisible static private final String INVOICE_PDF_ENDPOINT = '/v1/invoices/{{INVOICE_ID}}/download';
    @TestVisible static private final String INVOICE_GROUPS_ENDPOINT = '/v2/invoice-groups';
    @TestVisible static private final String ORDER_ENDPOINT = '/v2/orders';
    @TestVisible static private final String ORDER_PREVIEW_ENDPOINT = '/v2/order-intent/preview';
    @TestVisible static private final String ENTITLEMENT_DISPLAY_INFO_ENDPOINT = '/v1/entitlements/{{ENTITLEMENT_ID}}/display-info';
    @TestVisible static private final String ENTITLEMENT_DETAILS_ENDPOINT = '/v2/entitlements/{{ENTITLEMENT_ID}}/details';
    @TestVisible static private final String ENTITLEMENT_PARTNER_INFO_ENDPOINT = '/v1/entitlements/{{ENTITLEMENT_ID}}/partner-acquisition-info';
    @TestVisible static private final String OFFERINGS_ENDPOINT = '/v2/products/{{PRODUCT_ID}}/offerings';
    @TestVisible static private final Integer PROBE_TIMEOUT_MS = 10000;
    @TestVisible static private final Integer PROBE_ERROR_BODY_MAX_LENGTH = 4000;

    public static final String STATUS_HEALTHY = 'Healthy';
    public static final String STATUS_UNHEALTHY = 'Unhealthy';
    public static final String STATUS_OTHER_ERROR = 'Other_Error';
    public static final String STATUS_UNKNOWN = 'Unknown';

    @TestVisible private Map<String, String> namedCredentials = new Map<String, String> { };

    /**
     * Returns the singleton instance of the PortalCommerceApiClient
     * Creates a new instance if it does not exist
     * Gets the named credentials for the offices that the running user has access to
     * and puts them in a map with KEY = office and VALUE = named credential
     *
     * @return The instance of the PortalCommerceApiClient
     */
    static public PortalCommerceApiClient getInstance() {
        if (instance == null) {
            instance = new PortalCommerceApiClient();
            instance.namedCredentials = PortalCommerceApiAccessMgmt.getOfficesAccess();
        }
        return instance;
    }

    public HttpResponse getOfferings(String office, String productId, Integer pageSize, String nextId) {
        HttpRequest req = createRequestHeader(false);
        req.setEndpoint(generateEndpoint(office, OFFERINGS_ENDPOINT.replace('{{PRODUCT_ID}}', productId), pageSize, nextId, null));
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getProducts(String office, String invoiceGroupId, Integer pageSize, String nextId) {
        HttpRequest req = createRequestHeader(false);
        req.setEndpoint(generateEndpoint(office, PRODUCTS_ENDPOINT, pageSize, nextId, invoiceGroupId));
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getQuotes(String office, String invoiceGroupId, Integer pageSize, String nextId) {
        HttpRequest req = createRequestHeader(true);
        req.setEndpoint(generateEndpoint(office, QUOTES_ENDPOINT, pageSize, nextId, invoiceGroupId));
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getQuote(String office, String quoteId) {
        HttpRequest req = createRequestHeader(true);
        req.setEndpoint(generateEndpoint(office, QUOTE_ENDPOINT, null, null, null) + '/' + quoteId);
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getQuotePdf(String office, String quoteId) {
        HttpRequest req = createRequestHeader(true);
        String transactionAccountId = PortalCommerceApiAccessMgmt.getOfficeTransactionAccountId(office);
        req.setEndpoint(generateEndpoint(office, QUOTE_PDF_ENDPOINT.replace('{{QUOTE_ID}}', quoteId), null, null, null) + '?transactionAccountId=' + transactionAccountId);
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getInvoices(String office, String invoiceGroupId, Integer pageSize, String nextId) {
        HttpRequest req = createRequestHeader(true);
        req.setEndpoint(generateEndpoint(office, INVOICES_ENDPOINT, pageSize, nextId, invoiceGroupId));
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getPaidInvoices(String office, String invoiceGroupId, Integer pageSize, String nextId) {
        HttpRequest req = createRequestHeader(true);
        req.setEndpoint(generateEndpoint(office, INVOICES_ENDPOINT, pageSize, nextId, invoiceGroupId) + '&status=PAID');
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getInvoice(String office, String invoiceId) {
        HttpRequest req = createRequestHeader(true);
        req.setEndpoint(generateEndpoint(office, INVOICES_ENDPOINT, null, null, null) + '/' + invoiceId);
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getInvoicePdf(String office, String invoiceId) {
        HttpRequest req = createRequestHeader(true);
        String transactionAccountId = PortalCommerceApiAccessMgmt.getOfficeTransactionAccountId(office);
        req.setEndpoint(generateEndpoint(office, INVOICE_PDF_ENDPOINT.replace('{{INVOICE_ID}}', invoiceId), null, null, null) + '?transactionAccountId=' + transactionAccountId);
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getOrder(String office, String orderId) {
        HttpRequest req = createRequestHeader(true);
        req.setEndpoint(generateEndpoint(office, ORDER_ENDPOINT, null, null, null) + '/' + orderId);
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getOrderPreview(String office, String body) {
        HttpRequest req = createRequestHeader(true);
        req.setEndpoint(generateEndpoint(office, ORDER_PREVIEW_ENDPOINT, null, null, null));
        req.setHeader('Content-Type', 'application/json');
        req.setMethod('POST');
        req.setBody(body);

        System.debug(req);
        System.debug(req.getBody());
        return new Http().send(req);
    }

    public HttpResponse getInvoiceGroups(String office, Integer pageSize, String nextId) {
        HttpRequest req = createRequestHeader(true);
        req.setEndpoint(generateEndpoint(office, INVOICE_GROUPS_ENDPOINT, pageSize, nextId, null));
        req.setMethod('GET');
        return new Http().send(req);
    }

    /**
     * Lightweight health probe for a named credential. Uses GET /v2/invoice-groups?page-size=1
     * with the transaction-account header. Skips user office-permission checks and uses a short timeout.
     * 4xx/5xx are returned as results rather than thrown.
     */
    public ProbeResult probeOffice(String office) {
        ProbeResult result = new ProbeResult();
        result.office = office;
        Long started = System.currentTimeMillis();
        try {
            String namedCredentialName = PortalCommerceApiAccessMgmt.getNamedCredentialDeveloperName(office);
            result.namedCredentialName = namedCredentialName;
            if (String.isBlank(namedCredentialName) || !PortalCommerceApiAccessMgmt.namedCredentialExists(office)) {
                result.statusCode = 0;
                result.status = STATUS_OTHER_ERROR;
                result.errorMessage = 'Named Credential does not exist for the office: ' + office;
                return result;
            }

            HttpRequest req = createRequestHeader(true);
            req.setTimeout(PROBE_TIMEOUT_MS);
            req.setMethod('GET');
            req.setEndpoint(
                COMMERCE_API.replace('{{NAMED_CREDENTIAL}}', namedCredentialName)
                    + INVOICE_GROUPS_ENDPOINT
                    + '?page-size=1'
            );

            HttpResponse res = new Http().send(req);
            result.statusCode = res.getStatusCode();
            result.status = mapProbeStatus(res.getStatusCode());
            if (result.status != STATUS_HEALTHY) {
                result.errorMessage = truncateProbeBody(res.getBody());
            }
        } catch (Exception e) {
            result.statusCode = 0;
            result.status = STATUS_OTHER_ERROR;
            result.errorMessage = e.getMessage();
        } finally {
            result.responseTimeMs = System.currentTimeMillis() - started;
        }
        return result;
    }

    @TestVisible
    static String mapProbeStatus(Integer statusCode) {
        if (statusCode != null && statusCode >= 200 && statusCode < 300) {
            return STATUS_HEALTHY;
        }
        if (statusCode != null && statusCode >= 400 && statusCode < 500) {
            return STATUS_UNHEALTHY;
        }
        return STATUS_OTHER_ERROR;
    }

    @TestVisible
    static String truncateProbeBody(String body) {
        if (String.isBlank(body)) {
            return body;
        }
        return body.length() > PROBE_ERROR_BODY_MAX_LENGTH ? body.left(PROBE_ERROR_BODY_MAX_LENGTH) : body;
    }

    public class ProbeResult {
        public String office;
        public String namedCredentialName;
        public Integer statusCode;
        public String status;
        public String errorMessage;
        public Long responseTimeMs;
    }

    public HttpResponse getEntitlementDisplayInfo(String office, String entitlementId) {
        HttpRequest req = createRequestHeader(false);
        req.setEndpoint(generateEndpoint(office, ENTITLEMENT_DISPLAY_INFO_ENDPOINT.replace('{{ENTITLEMENT_ID}}', entitlementId), null, null, null));
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getEntitlementDetails(String office, String entitlementId) {
        HttpRequest req = createRequestHeader(false);
        req.setEndpoint(generateEndpoint(office, ENTITLEMENT_DETAILS_ENDPOINT.replace('{{ENTITLEMENT_ID}}', entitlementId), null, null, null));
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getEntitlementPartnerInfo(String office, String entitlementId) {
        HttpRequest req = createRequestHeader(false);
        req.setEndpoint(generateEndpoint(office, ENTITLEMENT_PARTNER_INFO_ENDPOINT.replace('{{ENTITLEMENT_ID}}', entitlementId), null, null, null));
        req.setMethod('GET');
        return new Http().send(req);
    }

    /**
     * Generates the endpoint URL for the Commerce API
     *
     * @param office The office to get the data from
     * @param function The function to call
     * @param pageSize The number of items to return
     * @param nextId The ID to start from
     * @param invoiceGroupId The invoice group ID
     *
     * @return The endpoint URL
     */
    @TestVisible
    private String generateEndpoint(String office, String function, Integer pageSize, String nextId, String invoiceGroupId) {
        if (!PortalCommerceApiAccessMgmt.namedCredentialExists(office)) {
            throw new PortalCommerceApiException('Named Credential does not exist for the office: ' + office);
        }
        if (!PortalCommerceApiAccessMgmt.hasOfficeAccess(office)) {
            throw new PortalCommerceApiException('User does not have access to the office: ' + office);
        }

        String officeAPiName = PortalCommerceApiAccessMgmt.translateApiNameToNamedCredential(office);
        String namedCredentialText = namedCredentials.get(officeAPiName) != null ? namedCredentials.get(officeAPiName) : '';
        String endpoint = COMMERCE_API.replace('{{NAMED_CREDENTIAL}}', namedCredentialText) + function;
        Map<String, String> parameterMap = new Map<String, String>();
        if (invoiceGroupId != null) {
            parameterMap.put('invoice-group', invoiceGroupId);
        }
        if (pageSize != null) {
            parameterMap.put('page-size', String.valueOf(pageSize));
        }
        if (nextId != null) {
            parameterMap.put('start-id', nextId);
        }

        if (!parameterMap.isEmpty()) {
            endpoint += '?';
            for (String key : parameterMap.keySet()) {
                endpoint += key + '=' + parameterMap.get(key) + '&';
            }
            endpoint = endpoint.removeEnd('&');
        }
        System.debug('*** ENDPOINT = ' + endpoint);
        return endpoint;
    }

    /**
     * Creates a new HttpRequest object with the necessary headers
     *
     * @param useTransactionAccount Whether to use the transaction account header
     *
     * @return The HttpRequest object
     */
    @TestVisible static HttpRequest createRequestHeader(Boolean useTransactionAccount) {
        HttpRequest req = new HttpRequest();
        req.setHeader('Accept', '*/*');
        req.setHeader('Authorization', 'Bearer {!$Credential.Password}');
        if (useTransactionAccount) {
            req.setHeader('X-transaction-account', '{!$Credential.Username}');
        }
        req.setTimeout(120000);
        return req;
    }
}