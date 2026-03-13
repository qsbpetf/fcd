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
}
