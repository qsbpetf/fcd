/**
 * Created by peterfriberg on 2024-06-05.
 */

public with sharing class PortalCommerceApiClient {

    static private PortalCommerceApiClient instance;
    static private final String COMMERCE_API = 'callout:AtlassianCommerceApi/commerce/api';
    static private final String PRODUCTS_ENDPOINT = '/v2/products';
    static private final String QUOTES_ENDPOINT = '/v1/quotes';
    static private final String INVOICES_ENDPOINT = '/v2/invoices';

    static public PortalCommerceApiClient getInstance() {
        if (instance == null) {
            instance = new PortalCommerceApiClient();
        }
        return instance;
    }

    public HttpResponse getProducts(Integer pageSize, String nextId) {
        HttpRequest req = new HttpRequest();
        String endpoint = COMMERCE_API + PRODUCTS_ENDPOINT;
        if (pageSize != null) {
            endpoint += '?page-size=' + pageSize;
        }
        if (nextId != null) {
            endpoint += (pageSize != null ? '&' : '?') + 'start-id=' + nextId;
        }
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer {!$Credential.Password}');
        return new Http().send(req);
    }

    public HttpResponse getQuotes(Integer pageSize, String nextId, String transactionAccountId) {
        HttpRequest req = new HttpRequest();
        String endpoint = COMMERCE_API + QUOTES_ENDPOINT;
        if (pageSize != null) {
            endpoint += '?page-size=' + pageSize;
        }
        if (nextId != null) {
            endpoint += (pageSize != null ? '&' : '?') + 'start-id=' + nextId;
        }
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer {!$Credential.Password}');
        req.setHeader('X-transaction-account', transactionAccountId);
        return new Http().send(req);
    }

    public HttpResponse getInvoices(Integer pageSize, String nextId, String transactionAccountId) {
        HttpRequest req = new HttpRequest();
        String endpoint = COMMERCE_API + INVOICES_ENDPOINT;
        if (pageSize != null) {
            endpoint += '?page-size=' + pageSize;
        }
        if (nextId != null) {
            endpoint += (pageSize != null ? '&' : '?') + 'start-id=' + nextId;
        }
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Authorization', 'Bearer {!$Credential.Password}');
        req.setHeader('X-transaction-account', transactionAccountId);
        return new Http().send(req);
    }
}