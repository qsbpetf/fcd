@IsTest
public with sharing class GeneralHttpCalloutMock implements HttpCalloutMock {
    private final Map<String, HttpResponse> responseMap;
    private final List<HttpRequest> requests;

    public GeneralHttpCalloutMock() {
        this.responseMap = new Map<String, HttpResponse>();

        HttpResponse resp = new HttpResponse();
        resp.setStatusCode(200);
        resp.setStatus('OK');
        resp.setBody('');

        this.responseMap.put('', resp);
        this.requests = new List<HttpRequest>();
    }

    public GeneralHttpCalloutMock(Integer defaultStatusCode, String defaultStatus, String defaultBody) {
        this.responseMap = new Map<String, HttpResponse>();

        HttpResponse resp = new HttpResponse();
        resp.setStatusCode(defaultStatusCode);
        resp.setStatus(defaultStatus);
        resp.setBody(defaultBody);

        this.responseMap.put('', resp);
        this.requests = new List<HttpRequest>();
    }

    public void addOkResponse(String key, String body) {
        HttpResponse resp = new HttpResponse();
        resp.setStatusCode(200);
        resp.setStatus('OK');
        resp.setBody(body);

        this.responseMap.put(key, resp);
    }

    public void addErrorResponse(String key, Integer statusCode, String body) {
        HttpResponse resp = new HttpResponse();
        resp.setStatusCode(statusCode);
        resp.setStatus('ERROR');
        resp.setBody(body);

        this.responseMap.put(key, resp);
    }

    public HttpResponse respond(HttpRequest req) {
        this.requests.add(req);

        for (String key : this.responseMap.keySet()) {
            if (String.isNotBlank(key) && req.getEndpoint().containsIgnoreCase(key)) {
                return this.responseMap.get(key);
            }
        }

        for (String key : this.responseMap.keySet()) {
            if (String.isNotBlank(key) && req.getBody() != null && req.getBody().containsIgnoreCase(key)) {
                return this.responseMap.get(key);
            }
        }

        return this.responseMap.get('');
    }

    public List<HttpRequest> getRequests() {
        return this.requests;
    }
}