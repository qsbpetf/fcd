/**
 * Created by peterfriberg on 2024-06-05.
 */

public with sharing class PortalCommerceApiClient {

    public class PortalCommerceApiException extends Exception {}

    static private PortalCommerceApiClient instance;
    static private final String COMMERCE_API = 'callout:{{NAMED_CREDENTIAL}}/commerce/api';
    static private final String PRODUCTS_ENDPOINT = '/v2/products';
    static private final String QUOTES_ENDPOINT = '/v1/quotes';
    static private final String INVOICES_ENDPOINT = '/v2/invoices';
    static private final String INVOICE_GROUPS_ENDPOINT = '/v2/invoice-groups';

    private Map<String, String> namedCredentials = new Map<String, String> { };

    static public PortalCommerceApiClient getInstance() {
        if (instance == null) {
            instance = new PortalCommerceApiClient();
            instance.namedCredentials = PortalCommerceApiAccessMgmt.getOfficesAccess();
        }
        return instance;
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

    public HttpResponse getInvoices(String office, String invoiceGroupId, Integer pageSize, String nextId) {
        HttpRequest req = createRequestHeader(true);
        req.setEndpoint(generateEndpoint(office, INVOICES_ENDPOINT, pageSize, nextId, invoiceGroupId));
        req.setMethod('GET');
        return new Http().send(req);
    }

    public HttpResponse getInvoiceGroups(String office, Integer pageSize, String nextId) {
        HttpRequest req = createRequestHeader(true);
        req.setEndpoint(generateEndpoint(office, INVOICE_GROUPS_ENDPOINT, pageSize, nextId, null));
        req.setMethod('GET');
        return new Http().send(req);
    }

    @TestVisible
    private String generateEndpoint(String office, String function, Integer pageSize, String nextId, String invoiceGroupId) {
        if (!PortalCommerceApiAccessMgmt.hasOfficeAccess(office)) {
            throw new PortalCommerceApiException('User does not have access to the office: ' + office);
        }
        if (!PortalCommerceApiAccessMgmt.namedCredentialExists(office)) {
            throw new PortalCommerceApiException('Named Credential does not exist for the office: ' + office);
        }

        String endpoint = COMMERCE_API.replace('{{NAMED_CREDENTIAL}}', this.namedCredentials.get(office)) + function;
        Map<String, String> parameterMap = new Map<String, String>();
        if (invoiceGroupId != null) {
            parameterMap.put('invoice-group-id', invoiceGroupId);
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

    @TestVisible static HttpRequest createRequestHeader(Boolean useTransactionAccount) {
        HttpRequest req = new HttpRequest();
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer {!$Credential.Password}');
        if (useTransactionAccount) {
            req.setHeader('X-transaction-account', '{!$Credential.Username}');
        }
        return req;
    }
}