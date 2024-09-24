/**
 * Created by peterfriberg on 2024-09-24.
 */

@IsTest
private class PortalInvoiceGroupSyncQueueableTest {

    private final static List<String> OFFICE_LIST = PortalCommerceApiAccessMgmt.getAllOffices();

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiClient mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiClient.class);
        mockServiceStub = (PortalCommerceApiClient) mockService.createStub();
        PortalCommerceApiInvoiceGroups.instance = new PortalCommerceApiInvoiceGroups();
        PortalCommerceApiInvoiceGroups.setApiClient(mockServiceStub);
    }

    @IsTest
    static void syncInvoiceGroupsHappyPath() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"data":[{"id":"123456","version":15,"name":"Invoice Group 1","slug":"SLUG","currency":"EUR","active":true,"shipToParty":{"name":"Ship To Party 1","id":"ABCDEF","taxId":"665544"}}]}');

        mockService
            .when('getInvoiceGroups')
            .thenReturn(response);

        Test.startTest();
        PortalInvoiceGroupSyncQueueable job = new PortalInvoiceGroupSyncQueueable();
        System.enqueueJob(job);
        Test.stopTest();

        System.assertEquals(0, job.currentOfficeIdx, 'Should have first office index');
        System.assertEquals(null, job.nextId, 'Should have first office index');

        List<InvoiceGroup__c> invoiceGroups = new List<InvoiceGroup__c>([
            SELECT
                Id, Name, AtlassianInvoiceGroupId__c, Version__c, Slug__c,
                CV_Subsidiary__c, ShipToPartyName__c, ShipToPartyVatTaxId__c,
                CurrencyIsoCode, Active__c, LastSynchronized__c
            FROM InvoiceGroup__c]);

        System.assertEquals(1, invoiceGroups.size(), 'Should have one invoice group');
        System.assertEquals('123456', invoiceGroups[0].AtlassianInvoiceGroupId__c, 'Wrong invoice group number');
        System.assertEquals(15, invoiceGroups[0].Version__c, 'Wrong invoice group version');
        System.assertEquals('Invoice Group 1', invoiceGroups[0].Name, 'Wrong invoice group name');
        System.assertEquals('SLUG', invoiceGroups[0].Slug__c, 'Wrong invoice group slug');
        System.assertEquals('EUR', invoiceGroups[0].CurrencyIsoCode, 'Wrong invoice group currency');
        System.assertEquals(true, invoiceGroups[0].Active__c, 'Wrong invoice group active');
        System.assertEquals('Ship To Party 1', invoiceGroups[0].ShipToPartyName__c, 'Wrong ship to party name');
        System.assertEquals(OFFICE_LIST[0], invoiceGroups[0].CV_Subsidiary__c, 'Wrong ship to party id');
        System.assertEquals('665544', invoiceGroups[0].ShipToPartyVatTaxId__c, 'Wrong ship to party tax id');
    }

    @IsTest
    static void syncInvoiceGroupsWithNextId() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"data":[{"id":"123456","version":15,"name":"Invoice Group 1","slug":"SLUG","currency":"EUR","active":true,"shipToParty":{"name":"Ship To Party 1","id":"ABCDEF","taxId":"665544"}}],"nextId": "NEXT_ID"}');

        mockService
            .when('getInvoiceGroups')
            .thenReturn(response);

        Test.startTest();
        PortalInvoiceGroupSyncQueueable job = new PortalInvoiceGroupSyncQueueable();
        System.enqueueJob(job);
        Test.stopTest();

        System.assertEquals(0, job.currentOfficeIdx, 'Should have first office index');
        System.assertEquals(null, job.nextId, 'Should have first office index');

        List<InvoiceGroup__c> invoiceGroups = new List<InvoiceGroup__c>([
            SELECT
                Id, Name, AtlassianInvoiceGroupId__c, Version__c, Slug__c,
                CV_Subsidiary__c, ShipToPartyName__c, ShipToPartyVatTaxId__c,
                CurrencyIsoCode, Active__c, LastSynchronized__c
            FROM InvoiceGroup__c]);

        System.assertEquals(1, invoiceGroups.size(), 'Should have one invoice group');
        System.assertEquals('123456', invoiceGroups[0].AtlassianInvoiceGroupId__c, 'Wrong invoice group number');
        System.assertEquals(15, invoiceGroups[0].Version__c, 'Wrong invoice group version');
        System.assertEquals('Invoice Group 1', invoiceGroups[0].Name, 'Wrong invoice group name');
        System.assertEquals('SLUG', invoiceGroups[0].Slug__c, 'Wrong invoice group slug');
        System.assertEquals('EUR', invoiceGroups[0].CurrencyIsoCode, 'Wrong invoice group currency');
        System.assertEquals(true, invoiceGroups[0].Active__c, 'Wrong invoice group active');
        System.assertEquals('Ship To Party 1', invoiceGroups[0].ShipToPartyName__c, 'Wrong ship to party name');
        System.assertEquals(OFFICE_LIST[job.currentOfficeIdx], invoiceGroups[0].CV_Subsidiary__c, 'Wrong ship to party id');
        System.assertEquals('665544', invoiceGroups[0].ShipToPartyVatTaxId__c, 'Wrong ship to party tax id');
    }

    @IsTest
    static void syncInvoiceGroupsNextOffice() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"data":[{"id":"123456","version":15,"name":"Invoice Group 1","slug":"SLUG","currency":"EUR","active":true,"shipToParty":{"name":"Ship To Party 1","id":"ABCDEF","taxId":"665544"}}]}');

        mockService
            .when('getInvoiceGroups')
            .thenReturn(response);

        Test.startTest();
        PortalInvoiceGroupSyncQueueable job = new PortalInvoiceGroupSyncQueueable(1);
        System.enqueueJob(job);
        Test.stopTest();

        System.assertEquals(1, job.currentOfficeIdx, 'Should have next office index');

        List<InvoiceGroup__c> invoiceGroups = new List<InvoiceGroup__c>([
            SELECT
                Id, Name, AtlassianInvoiceGroupId__c, Version__c, Slug__c,
                CV_Subsidiary__c, ShipToPartyName__c, ShipToPartyVatTaxId__c,
                CurrencyIsoCode, Active__c, LastSynchronized__c
            FROM InvoiceGroup__c]);

        System.assertEquals(1, invoiceGroups.size(), 'Should have one invoice group');
        System.assertEquals('123456', invoiceGroups[0].AtlassianInvoiceGroupId__c, 'Wrong invoice group number');
        System.assertEquals(15, invoiceGroups[0].Version__c, 'Wrong invoice group version');
        System.assertEquals('Invoice Group 1', invoiceGroups[0].Name, 'Wrong invoice group name');
        System.assertEquals('SLUG', invoiceGroups[0].Slug__c, 'Wrong invoice group slug');
        System.assertEquals('EUR', invoiceGroups[0].CurrencyIsoCode, 'Wrong invoice group currency');
        System.assertEquals(true, invoiceGroups[0].Active__c, 'Wrong invoice group active');
        System.assertEquals('Ship To Party 1', invoiceGroups[0].ShipToPartyName__c, 'Wrong ship to party name');
        System.assertEquals(OFFICE_LIST[job.currentOfficeIdx], invoiceGroups[0].CV_Subsidiary__c, 'Wrong ship to party id');
        System.assertEquals('665544', invoiceGroups[0].ShipToPartyVatTaxId__c, 'Wrong ship to party tax id');
    }

    @IsTest
    static void syncInvoiceGroupsSameOfficeNextId() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"data":[{"id":"123456","version":15,"name":"Invoice Group 1","slug":"SLUG","currency":"EUR","active":true,"shipToParty":{"name":"Ship To Party 1","id":"ABCDEF","taxId":"665544"}}],"nextId": "NEXT_ID"}');

        mockService
            .when('getInvoiceGroups')
            .thenReturn(response);

        Test.startTest();
        PortalInvoiceGroupSyncQueueable job = new PortalInvoiceGroupSyncQueueable(2, 'NEXT_ID');
        System.enqueueJob(job);
        Test.stopTest();

        System.assertEquals(2, job.currentOfficeIdx, 'Should have third office index');

        List<InvoiceGroup__c> invoiceGroups = new List<InvoiceGroup__c>([
            SELECT
                Id, Name, AtlassianInvoiceGroupId__c, Version__c, Slug__c,
                CV_Subsidiary__c, ShipToPartyName__c, ShipToPartyVatTaxId__c,
                CurrencyIsoCode, Active__c, LastSynchronized__c
            FROM InvoiceGroup__c]);

        System.assertEquals(1, invoiceGroups.size(), 'Should have one invoice group');
        System.assertEquals('123456', invoiceGroups[0].AtlassianInvoiceGroupId__c, 'Wrong invoice group number');
        System.assertEquals(15, invoiceGroups[0].Version__c, 'Wrong invoice group version');
        System.assertEquals('Invoice Group 1', invoiceGroups[0].Name, 'Wrong invoice group name');
        System.assertEquals('SLUG', invoiceGroups[0].Slug__c, 'Wrong invoice group slug');
        System.assertEquals('EUR', invoiceGroups[0].CurrencyIsoCode, 'Wrong invoice group currency');
        System.assertEquals(true, invoiceGroups[0].Active__c, 'Wrong invoice group active');
        System.assertEquals('Ship To Party 1', invoiceGroups[0].ShipToPartyName__c, 'Wrong ship to party name');
        System.assertEquals(OFFICE_LIST[job.currentOfficeIdx], invoiceGroups[0].CV_Subsidiary__c, 'Wrong ship to party id');
        System.assertEquals('665544', invoiceGroups[0].ShipToPartyVatTaxId__c, 'Wrong ship to party tax id');
    }

    @IsTest
    static void syncInvoiceGroupOfficeError() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(500);
        response.setStatus('Internal Server Error');
        response.setBody('{"error":"Internal Server Error"}');

        mockService
            .when('getInvoiceGroups')
            .thenReturn(response);

        Test.startTest();
        PortalInvoiceGroupSyncQueueable job = new PortalInvoiceGroupSyncQueueable();
        System.enqueueJob(job);
        Test.stopTest();

        List<InvoiceGroup__c> invoiceGroups = new List<InvoiceGroup__c>([
            SELECT Id
            FROM InvoiceGroup__c]);
        System.assertEquals(0, invoiceGroups.size(), 'Should have no invoice groups');
    }
}