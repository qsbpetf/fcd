/**
 * Unit tests for AtlassianDealRegApiRegistrations.
 */
@IsTest
private class AtlassianDealRegApiRegistrationsTest {

    private static final String SEARCH_RESPONSE = '{'
        + '"registrations":['
        + '{"id":"D-12345","parentRegistrationId":null,"dealName":"Test Deal","programType":"DEAL_REGISTRATION",'
        + '"status":"DRAFT","customerDomain":"example.com","partnerSubmittedOpportunityNumber":"OPP-001",'
        + '"estimatedRevenue":"10000","expirationDate":"2024-12-31","createdAt":"2024-01-15T10:00:00Z","lastModifiedAt":"2024-01-15T10:00:00Z"}'
        + '],'
        + '"pagination":{"pageSize":10,"nextPageToken":"token123","hasNext":true,"hasPrevious":false,"links":{"self":"https://api.example.com/search","next":"https://api.example.com/search?pageToken=token123"}}'
        + '}';

    private static final String SEARCH_EMPTY_RESPONSE = '{"registrations":[],"pagination":{"pageSize":10,"nextPageToken":null,"hasNext":false,"hasPrevious":false}}';

    private static final String API_ERROR_RESPONSE = '{"statusCode":403,"message":"Forbidden","errors":{}}';

    private static final String DEAL_REG_RESPONSE = '{'
        + '"id":"D-91304096","parentRegistrationId":null,"dealName":"HUSQVARNA SERVER 2 DC","programType":"Deal Registration",'
        + '"status":"Use Child Registrations","partnerSubmittedOpportunityNumber":null,"partnerSalesRepresentativeEmailId":"armin.kardar@eficode.com",'
        + '"opportunityNumber":null,"lastModifiedAt":"2023-12-05T15:02:45.000Z","extensionStatus":null,"expirationDate":"2024-06-02",'
        + '"estimatedRevenue":"60000.0","customerDomain":"husqvarnagroup.com","customerContactEmailId":"oliver.kaupin@husqvarnagroup.com",'
        + '"createdAt":"2023-12-05T15:02:38.000Z","approvalDate":null,"submissionDate":"2023-12-05"}';

    private static final String SERVICE_REG_RESPONSE = '{'
        + '"id":"CD-12345678","parentRegistrationId":"D-91304096","dealName":"Test Service","programType":"SERVICE_REGISTRATION",'
        + '"status":"DRAFT","estimatedRevenue":"10000.0","customerDomain":"example.com"}';

    @IsTest
    static void testSetApiClient() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('registrations/v1/search', SEARCH_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianDealRegApiRegistrations svc = AtlassianDealRegApiRegistrations.getInstance();
        AtlassianDealRegApiRegistrations.setApiClient(AtlassianDealRegApiClient.getInstance());

        Test.startTest();
        AtlassianDealRegApiRegistrations.SearchRegistrationsResponse result = svc.searchRegistrations(
            '0012000000yYBawAAG',
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            10,
            null,
            null,
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, result.registrations, 'Should return registrations after setApiClient');
        System.assertEquals(1, result.registrations.size(), 'Should have 1 registration');
    }

    @IsTest
    static void testSearchRegistrationsStatic() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('registrations/v1/search', SEARCH_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        AtlassianDealRegApiRegistrations.SearchRegistrationsResponse result =
            AtlassianDealRegApiRegistrations.searchRegistrationsStatic(
                '0012000000yYBawAAG',
                'DRAFT,SUBMITTED',
                null,
                null,
                'DEAL_REGISTRATION',
                null,
                '2024-01-01',
                '2024-12-31',
                10,  // pageSize
                null,
                'CREATED_AT',
                'DESC'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(1, result.registrations.size(), 'Should have 1 registration');
        System.assertEquals('D-12345', result.registrations[0].id, 'Wrong registration id');
        System.assertEquals('Test Deal', result.registrations[0].dealName, 'Wrong deal name');
        System.assertEquals('DEAL_REGISTRATION', result.registrations[0].programType, 'Wrong program type');
        System.assertEquals('DRAFT', result.registrations[0].status, 'Wrong status');
        System.assertEquals('example.com', result.registrations[0].customerDomain, 'Wrong customer domain');
        System.assertNotEquals(null, result.pagination, 'Pagination should not be null');
        System.assertEquals(10, result.pagination.pageSize, 'Wrong page size');
        System.assertEquals(true, result.pagination.hasNext, 'Should have next page');
        System.assertEquals('token123', result.pagination.nextPageToken, 'Wrong next page token');
    }

    @IsTest
    static void testSearchRegistrationsEmptyResult() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('registrations/v1/search', SEARCH_EMPTY_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        AtlassianDealRegApiRegistrations.SearchRegistrationsResponse result =
            AtlassianDealRegApiRegistrations.searchRegistrationsStatic(
                '0012000000yYBawAAG',
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                10,  // pageSize
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.registrations.size(), 'Should have 0 registrations');
        System.assertEquals(false, result.pagination.hasNext, 'Should not have next page');
    }

    @IsTest
    static void testSearchRegistrationsWithPageToken() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('registrations/v1/search', SEARCH_EMPTY_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        AtlassianDealRegApiRegistrations.searchRegistrationsStatic(
            '0012000000yYBawAAG',
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            25,  // pageSize
            'pageToken123',
            'LAST_MODIFIED_AT',
            'ASC'
        );
        Test.stopTest();

        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('pageToken=pageToken123'), 'Missing pageToken');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('limit=25'), 'Missing limit');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('sortBy=LAST_MODIFIED_AT'), 'Missing sortBy');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('sortOrder=ASC'), 'Missing sortOrder');
    }

    @IsTest
    static void testSearchRegistrationsThrowsWhenPartnerAccountIdBlank() {
        try {
            AtlassianDealRegApiRegistrations.searchRegistrationsStatic(
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                10,  // pageSize
                null,
                null,
                null
            );
            System.assert(false, 'Expected exception');
        } catch (AtlassianDealRegApiClient.AtlassianDealRegApiException e) {
            System.assert(e.getMessage().contains('partnerAccountId is required'), 'Wrong exception message');
        }
    }

    @IsTest
    static void testSearchRegistrationsErrorHandling() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addErrorResponse('registrations/v1/search', 403, API_ERROR_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        try {
            AtlassianDealRegApiRegistrations.searchRegistrationsStatic(
                '0012000000yYBawAAG',
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                10,  // pageSize
                null,
                null,
                null
            );
            System.assert(false, 'Expected exception');
        } catch (AtlassianDealRegApiClient.AtlassianDealRegApiException e) {
            System.assert(e.getMessage().contains('Search failed'), 'Wrong exception message');
        }
    }

    @IsTest
    static void testGetRegistrationStaticDeal() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('registrations/v1/deals', DEAL_REG_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Map<String, Object> result = AtlassianDealRegApiRegistrations.getRegistrationStatic(
            '0012000000yYBawAAG',
            'D-91304096',
            'DEAL_REGISTRATION'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('D-91304096', result.get('id'), 'Wrong id');
        System.assertEquals('HUSQVARNA SERVER 2 DC', result.get('dealName'), 'Wrong deal name');
        System.assertEquals('Use Child Registrations', result.get('status'), 'Wrong status');
        System.assertEquals('60000.0', result.get('estimatedRevenue'), 'Wrong estimated revenue');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('deals/D-91304096'), 'Wrong endpoint');
    }

    @IsTest
    static void testGetRegistrationStaticService() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('registrations/v1/services', SERVICE_REG_RESPONSE);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Map<String, Object> result = AtlassianDealRegApiRegistrations.getRegistrationStatic(
            '0012000000yYBawAAG',
            'CD-12345678',
            'SERVICE_REGISTRATION'
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('CD-12345678', result.get('id'), 'Wrong id');
        System.assertEquals('Test Service', result.get('dealName'), 'Wrong deal name');
        System.assert(mock.getRequests()[0].getEndpoint().containsIgnoreCase('services/CD-12345678'), 'Wrong endpoint');
    }

    @IsTest
    static void testGetRegistrationStaticThrowsWhenPartnerAccountIdBlank() {
        try {
            AtlassianDealRegApiRegistrations.getRegistrationStatic(null, 'D-123', 'DEAL_REGISTRATION');
            System.assert(false, 'Expected exception');
        } catch (AtlassianDealRegApiClient.AtlassianDealRegApiException e) {
            System.assert(e.getMessage().contains('partnerAccountId is required'), 'Wrong exception message');
        }
    }

    @IsTest
    static void testGetRegistrationStaticThrowsWhenRegistrationIdBlank() {
        try {
            AtlassianDealRegApiRegistrations.getRegistrationStatic('0012000000yYBawAAG', null, 'DEAL_REGISTRATION');
            System.assert(false, 'Expected exception');
        } catch (AtlassianDealRegApiClient.AtlassianDealRegApiException e) {
            System.assert(e.getMessage().contains('registrationId is required'), 'Wrong exception message');
        }
    }
}
