/**
 * Unit tests for AtlassianDealRegApiPartnerAccounts (partner accounts service layer with cache).
 */
@IsTest
private class AtlassianDealRegApiPartnerAccountsTest {

    private static final String PARTNER_ACCOUNTS_RESPONSE = '{"partnerAccounts":[{"partnerId":"0012000000yYBawAAG","accountName":"Eficode Finland","roles":["DEVELOPER","PARTNER_PRINCIPAL"],"isPrimary":true}]}';
    private static final String API_ERROR_RESPONSE = '{"statusCode":400,"message":"Invalid request","errors":{}}';

    @IsTest
    static void testCacheHit() {
        deleteExistingCache();
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('partner-accounts/v1/list', PARTNER_ACCOUNTS_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianDealRegApiPartnerAccounts svc = AtlassianDealRegApiPartnerAccounts.getInstance();

        Test.startTest();
        AtlassianDealRegApiPartnerAccounts.PartnerAccountsResponse r1 = svc.getPartnerAccounts(false);
        AtlassianDealRegApiPartnerAccounts.PartnerAccountsResponse r2 = svc.getPartnerAccounts(false);
        Test.stopTest();

        System.assertEquals(1, mock.getRequests().size(), 'Second call should hit cache, only 1 API call');
        System.assertNotEquals(null, r1.partnerAccounts, 'First result should have partnerAccounts');
        System.assertEquals(1, r1.partnerAccounts.size(), 'First should have 1 account');
        System.assertEquals(r1.partnerAccounts[0].partnerId, r2.partnerAccounts[0].partnerId, 'Both results should match');
    }

    @IsTest
    static void testCacheMiss() {
        deleteExistingCache();
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('partner-accounts/v1/list', PARTNER_ACCOUNTS_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianDealRegApiPartnerAccounts svc = AtlassianDealRegApiPartnerAccounts.getInstance();

        Test.startTest();
        AtlassianDealRegApiPartnerAccounts.PartnerAccountsResponse result = svc.getPartnerAccounts(false);
        Test.stopTest();

        System.assertEquals(1, mock.getRequests().size(), 'Should call API on cache miss');
        System.assertNotEquals(null, result.partnerAccounts, 'Result should have partnerAccounts');
        System.assertEquals(1, result.partnerAccounts.size(), 'Should have 1 account');
    }

    @IsTest
    static void testStaleCache() {
        deleteExistingCache();
        insert new ApiResponseCache__c(
            CacheKey__c = 'PartnerAccounts',
            Name = 'PartnerAccounts',
            ResponseJson__c = PARTNER_ACCOUNTS_RESPONSE
        );

        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('partner-accounts/v1/list', PARTNER_ACCOUNTS_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianDealRegApiPartnerAccounts.ttlMinutes = 0;
        AtlassianDealRegApiPartnerAccounts svc = AtlassianDealRegApiPartnerAccounts.getInstance();

        Test.startTest();
        AtlassianDealRegApiPartnerAccounts.PartnerAccountsResponse result = svc.getPartnerAccounts(false);
        Test.stopTest();

        System.assertEquals(1, mock.getRequests().size(), 'Stale cache should trigger API call');
        System.assertNotEquals(null, result.partnerAccounts, 'Result should have partnerAccounts');
    }

    @IsTest
    static void testApiErrorNoCacheWrite() {
        deleteExistingCache();
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addErrorResponse('partner-accounts/v1/list', 400, API_ERROR_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianDealRegApiPartnerAccounts svc = AtlassianDealRegApiPartnerAccounts.getInstance();

        Test.startTest();
        AtlassianDealRegApiPartnerAccounts.PartnerAccountsResponse result = svc.getPartnerAccounts(false);
        Test.stopTest();

        System.assertEquals(1, mock.getRequests().size(), 'Should have called API');
        List<ApiResponseCache__c> cached = [SELECT Id FROM ApiResponseCache__c WHERE CacheKey__c = 'PartnerAccounts'];
        System.assertEquals(0, cached.size(), 'Should not cache on non-200 response');
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.partnerAccounts, 'partnerAccounts should be empty list');
        System.assertEquals(0, result.partnerAccounts.size(), 'Should have empty list on error');
    }

    @IsTest
    static void testSetApiClient() {
        deleteExistingCache();
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('partner-accounts/v1/list', PARTNER_ACCOUNTS_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianDealRegApiPartnerAccounts svc = AtlassianDealRegApiPartnerAccounts.getInstance();
        AtlassianDealRegApiPartnerAccounts.setApiClient(AtlassianDealRegApiClient.getInstance());

        Test.startTest();
        AtlassianDealRegApiPartnerAccounts.PartnerAccountsResponse result = svc.getPartnerAccounts(true);
        Test.stopTest();

        System.assertNotEquals(null, result.partnerAccounts, 'Should return partner accounts after setApiClient');
        System.assertEquals(1, result.partnerAccounts.size(), 'Should have 1 account');
    }

    @IsTest
    static void testGetPartnerAccountsStatic() {
        deleteExistingCache();
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('partner-accounts/v1/list', PARTNER_ACCOUNTS_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        AtlassianDealRegApiPartnerAccounts.PartnerAccountsResponse result = AtlassianDealRegApiPartnerAccounts.getPartnerAccountsStatic(false);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.partnerAccounts, 'partnerAccounts should not be null');
        System.assertEquals(1, result.partnerAccounts.size(), 'Should have 1 partner account');
    }

    @IsTest
    static void testAForceRefresh() {  // "A" prefix ensures this runs first (no DML before callout)
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('partner-accounts/v1/list', PARTNER_ACCOUNTS_RESPONSE);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, mock);
        AtlassianDealRegApiPartnerAccounts.PartnerAccountsResponse result = AtlassianDealRegApiPartnerAccounts.getPartnerAccountsStatic(true);
        Test.stopTest();

        System.assertEquals(1, mock.getRequests().size(), 'forceRefresh=true should call API');
        System.assertNotEquals(null, result.partnerAccounts, 'Result should have partnerAccounts');
    }

    private static void deleteExistingCache() {
        delete [SELECT Id FROM ApiResponseCache__c WHERE CacheKey__c = 'PartnerAccounts'];
    }
}