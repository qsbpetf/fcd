/**
 * Unit tests for AtlassianDealRegApiClient.
 */
@IsTest
private class AtlassianDealRegApiClientTest {

    private static final String PARTNER_ACCOUNTS_RESPONSE = '{"partnerAccounts":[{"partnerId":"0012000000yYBawAAG","accountName":"Eficode Finland","roles":["DEVELOPER","PARTNER_PRINCIPAL"],"isPrimary":true}]}';
    private static final String DRAFT_CREATION_RESPONSE = '{"id":"D-12345","status":"DRAFT"}';
    private static final String API_ERROR_RESPONSE = '{"statusCode":400,"message":"Invalid request","errors":{}}';

    @IsTest
    static void testGetSingletonInstance() {
        AtlassianDealRegApiClient instance1 = AtlassianDealRegApiClient.getInstance();
        AtlassianDealRegApiClient instance2 = AtlassianDealRegApiClient.getInstance();
        System.assertEquals(instance1, instance2, 'Instances should be the same');
    }

    @IsTest
    static void testListPartnerAccounts() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('partner-accounts/v1/list', PARTNER_ACCOUNTS_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianDealRegApiClient client = AtlassianDealRegApiClient.getInstance();

        Test.startTest();
        HttpResponse resp = client.listPartnerAccounts();
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals('OK', resp.getStatus(), 'Wrong status');
        System.assertEquals(PARTNER_ACCOUNTS_RESPONSE, resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('partner-accounts/v1/list'), 'Wrong endpoint');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('callout:Atlassian_deal_Reg_API'), 'Wrong named credential');
        System.assertEquals('GET', mock.getRequests()[0].getMethod(), 'Wrong method');
    }

    @IsTest
    static void testCreateDealRegistration() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addErrorResponse('registrations/v1/deals', 201, DRAFT_CREATION_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianDealRegApiClient client = AtlassianDealRegApiClient.getInstance();
        String body = '{"dealName":"Test Deal","programType":"DEAL_REGISTRATION"}';

        Test.startTest();
        HttpResponse resp = client.createDealRegistration('0012000000yYBawAAG', body);
        Test.stopTest();

        System.assertEquals(201, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals(DRAFT_CREATION_RESPONSE, resp.getBody(), 'Wrong body');
        System.assertEquals(1, mock.getRequests().size(), 'Wrong number of requests');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('registrations/v1/deals'), 'Wrong endpoint');
        System.assertNotEquals(null, mock.getRequests()[0].getHeader('X-Partner-Account-Id'), 'Partner header required');
        System.assertEquals('0012000000yYBawAAG', mock.getRequests()[0].getHeader('X-Partner-Account-Id'), 'Wrong partner account id');
        System.assertEquals('POST', mock.getRequests()[0].getMethod(), 'Wrong method');
    }

    @IsTest
    static void testCreateDealRegistrationErrorHandling() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addErrorResponse('registrations/v1/deals', 400, API_ERROR_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianDealRegApiClient client = AtlassianDealRegApiClient.getInstance();

        Test.startTest();
        HttpResponse resp = client.createDealRegistration('0012000000yYBawAAG', '{}');
        Test.stopTest();

        System.assertEquals(400, resp.getStatusCode(), 'Wrong status code');
        System.assertEquals(API_ERROR_RESPONSE, resp.getBody(), 'Wrong error body');
    }

    @IsTest
    static void testSearchRegistrations() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('registrations/v1/search', '{"registrations":[],"pagination":{}}');
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianDealRegApiClient client = AtlassianDealRegApiClient.getInstance();
        Map<String, String> params = new Map<String, String>{
            'limit' => '10',
            'pageToken' => 'token123'
        };

        Test.startTest();
        HttpResponse resp = client.searchRegistrations('0012000000yYBawAAG', params);
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('registrations/v1/search'), 'Wrong endpoint');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('limit=10'), 'Missing limit param');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('pageToken'), 'Missing pageToken param');
        System.assertEquals('0012000000yYBawAAG', mock.getRequests()[0].getHeader('X-Partner-Account-Id'), 'Wrong partner account id');
    }

    @IsTest
    static void testGetDealRegistration() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('registrations/v1/deals/D-123', '{"id":"D-123","status":"DRAFT"}');
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianDealRegApiClient client = AtlassianDealRegApiClient.getInstance();

        Test.startTest();
        HttpResponse resp = client.getDealRegistration('0012000000yYBawAAG', 'D-123');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('registrations/v1/deals/D-123'), 'Wrong endpoint');
    }

    @IsTest
    static void testGetJobStatus() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('jobs/v1/job-123/status', '{"jobId":"job-123","status":"COMPLETED"}');
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianDealRegApiClient client = AtlassianDealRegApiClient.getInstance();

        Test.startTest();
        HttpResponse resp = client.getJobStatus('0012000000yYBawAAG', 'job-123');
        Test.stopTest();

        System.assertEquals(200, resp.getStatusCode(), 'Wrong status code');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('jobs/v1/job-123/status'), 'Wrong endpoint');
    }

    @IsTest
    static void testCreateRequestHeaderWithPartnerAccount() {
        HttpRequest req = AtlassianDealRegApiClient.createRequestHeader(true, '0012000000yYBawAAG');
        System.assertEquals('application/json', req.getHeader('Accept'), 'Wrong Accept header');
        System.assertEquals('0012000000yYBawAAG', req.getHeader('X-Partner-Account-Id'), 'Wrong X-Partner-Account-Id');
    }

    @IsTest
    static void testCreateRequestHeaderWithoutPartnerAccount() {
        HttpRequest req = AtlassianDealRegApiClient.createRequestHeader(false, null);
        System.assertEquals('application/json', req.getHeader('Accept'), 'Wrong Accept header');
        System.assertEquals(null, req.getHeader('X-Partner-Account-Id'), 'Should not have X-Partner-Account-Id');
    }

    @IsTest
    static void testPartnerAccountsServiceLayer() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('partner-accounts/v1/list', PARTNER_ACCOUNTS_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        AtlassianDealRegApiPartnerAccounts.PartnerAccountsResponse result = AtlassianDealRegApiPartnerAccounts.getPartnerAccountsStatic();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.partnerAccounts, 'partnerAccounts should not be null');
        System.assertEquals(1, result.partnerAccounts.size(), 'Should have 1 partner account');
        System.assertEquals('0012000000yYBawAAG', result.partnerAccounts[0].partnerId, 'Wrong partnerId');
        System.assertEquals('Eficode Finland', result.partnerAccounts[0].accountName, 'Wrong accountName');
        System.assertEquals(true, result.partnerAccounts[0].isPrimary, 'Should be primary');
    }
}
