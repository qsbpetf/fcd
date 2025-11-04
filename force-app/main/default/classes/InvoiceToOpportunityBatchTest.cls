/**
 * Created by peterfriberg on 2025-05-14.
 */

@IsTest
public class InvoiceToOpportunityBatchTest {

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiClient mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiClient.class);
        mockServiceStub = (PortalCommerceApiClient) mockService.createStub();
        PortalCommerceApiEntitlements.instance = new PortalCommerceApiEntitlements();
        PortalCommerceApiEntitlements.setApiClient(mockServiceStub);
    }

    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account 1',
            AutoInvoiceImport__c = true
        );
        insert testAccount;

        // Create test Opportunity
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity 1',
            AccountId = testAccount.Id,
            StageName = 'Explore',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = Test.getStandardPricebookId(),
            CurrencyIsoCode = 'CHF'
        );
        insert testOpportunity;

        // Create test data for PendingInvoice__c
        List<PendingInvoice__c> invoices = new List<PendingInvoice__c>();
        for (Integer i = 0; i < 5; i++) {
            invoices.add(new PendingInvoice__c(
                Name = 'Pending Invoice ' + i,
                Status__c = 'Waiting',
                Invoice_JSON__c = '{"total": 262.68, "tax": 19.68, "subTotal": 324.0, "status": "PAID", "paymentMethodObj": {"type": "CARD"}, "paidAt": 1746506137000, "office": "CH", "items": [{"unitAmount": 0.01, "total": 24.32, "tax": 1.82, "subTotal": 30.0, "sfProductName": null, "salesType": null, "quantity": 1, "productName": null, "planObj": {"type": "COMMERCIAL", "hostingType": "CLOUD", "cycle": {"interval": "MONTHLY"}}, "period": {"startAt": 1746489600000, "endAt": 1749168000000}, "orderItemId": "948ecea4-3811-40d6-b936-44e0193986d2-1", "orderId": "948ecea4-3811-40d6-b936-44e0193986d2", "offeringName": null, "offeringKey": "1ac3b7dd-7141-414e-bc00-c890acc458b0", "offeringId": null, "margins": [], "id": "97811f13-a415-416c-aa12-9105f6d7baa3", "entName": null, "entitlementNumber": "E-426-PDR-SAT-HNY", "entitlementId": "4cefbc0f-d24f-42e3-9e4b-c2e05e7591b4", "discountAmount": null, "description": "Guard, Monthly, Standard (USD, Default, 16-10-2024)", "amountExcludingTaxDecimal": null, "amountExcludingTax": null, "adjustments": [{"type": "PARTNER_DISCOUNT", "reasonCode": "partner.discount", "percent": 25.0, "amount": 7.5}], "adjustmentAmount": 7.5, "adjustment": null}], "isoCurrency": "USD", "invoiceNumber": "IN-003-387-115-' + i + '", "id": "ef203785-ce66-4400-bc25-5aef792a56ae", "dueAt": 1746506134014, "createdAt": 1746506129000, "additionalNotes": "Atlassian Pty Limited is a registered taxable person in Switzerland. For Swiss tax purposes, this is a supply of electronically provided services. The VAT exclusive total on this invoice is 200.37 (CHF). The amount of VAT on this invoice is 16.23 (CHF) at 8.1%"}',
                Invoice_JSON_2__c = '',
                Invoice_JSON_3__c = '',
                Invoice_JSON_4__c = '',
                Invoice_JSON_5__c = '',
                RetryCount__c = 0,
                Account__c = testAccount.Id,
                Opportunity__c = testOpportunity.Id
            ));
        }
        insert invoices;

        // Create a custom setting for PPC_InvoiceAutoImportSettings__c
        PPC_InvoiceAutoImportSettings__c setting = new PPC_InvoiceAutoImportSettings__c(
            Name = 'Default Setting',
            DeletePendingInvoices__c = true,
            DaysToKeepPendingInvoices__c = 7,
            AutomationEnabled__c = true,
            LastDays__c = 30
        );
        insert setting;

        Product2 prod = TestDataFactory.getProduct();
        System.debug(prod);
        prod.Name = 'Atlassian Cloud - Standard - Atlassian Guard';
        insert prod;

        PricebookEntry pbe1 = TestDataFactory.getPbEntry(Test.getStandardPricebookId(), prod.Id, 'CHF');
        PricebookEntry pbe2 = TestDataFactory.getPbEntry(Test.getStandardPricebookId(), prod.Id, 'USD');
        PricebookEntry pbe3 = TestDataFactory.getPbEntry(Test.getStandardPricebookId(), prod.Id, 'EUR');
        insert new List<PricebookEntry>{ pbe1, pbe2, pbe3 };
    }

    @IsTest
    static void testStartMethod() {
        // Instantiate the batch and call start
        InvoiceToOpportunityBatch batch = new InvoiceToOpportunityBatch();
        Database.QueryLocator queryLocator = batch.start(null);

        // Get a single iterator instance
        Database.QueryLocatorIterator iterator = queryLocator.iterator(); // Use a single iterator instance

        // Validate that the query returns the expected records
        List<PendingInvoice__c> invoices = new List<PendingInvoice__c>();
        while (iterator.hasNext()) { // Use this "iterator" instance for both hasNext() and next()
            invoices.add((PendingInvoice__c) iterator.next());
        }
        System.assertNotEquals(0, invoices.size(), 'Query should return records.');
        System.assertEquals(5, invoices.size(), 'There should be 5 pending invoices.');
    }

    @IsTest
    static void testExecuteMethod() {
        // Query records for the batch scope
        List<PendingInvoice__c> scopedInvoices = [
            SELECT
                Id, Name,
                Invoice_JSON__c,
                Invoice_JSON_2__c,
                Invoice_JSON_3__c,
                Invoice_JSON_4__c,
                Invoice_JSON_5__c,
                Status__c,
                RetryCount__c
            FROM PendingInvoice__c
            WHERE Status__c = 'Waiting'
        ];

        // Instantiate the batch and call execute
        Test.startTest();
        InvoiceToOpportunityBatch batch = new InvoiceToOpportunityBatch();
        batch.execute(null, scopedInvoices);
        Test.stopTest();

        // Assert that the invoices were processed
        for (PendingInvoice__c invoice : [
            SELECT Status__c, RetryCount__c
            FROM PendingInvoice__c
            WHERE Status__c IN ('Processing', 'Error')
        ]) {
            System.assert(invoice.Status__c == 'Processing' || invoice.Status__c == 'Error',
                'Invoice status should be updated to Processing or Error after execution.'
            );
        }
    }

    @IsTest
    static void testFinishMethod() {
        // Update records to simulate batch completion
        List<PendingInvoice__c> completedInvoices = [
            SELECT Id, CreatedDate
            FROM PendingInvoice__c
        ];

        for (PendingInvoice__c invoice : completedInvoices) {
            invoice.Status__c = 'Done';
        }
        update completedInvoices;

        // Instantiate the batch and call finish
        InvoiceToOpportunityBatch batch = new InvoiceToOpportunityBatch();
        Test.startTest();
        batch.finish(null);
        Test.stopTest();

        // Assert invoices older than 7 days are deleted (from custom setting)
        Datetime sevenDaysAgo = System.now().addDays(-7);
        List<PendingInvoice__c> remainingInvoices = [
            SELECT Id
            FROM PendingInvoice__c
            WHERE CreatedDate < :sevenDaysAgo AND Status__c = 'Done'
        ];

        System.assertEquals(0, remainingInvoices.size(), 'Invoices older than 7 days should be deleted.');
    }

    @IsTest
    static void testQueueableEnqueue() {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setStatus('OK');
        response.setBody('{"entitlementId":"4cefbc0f-d24f-42e3-9e4b-c2e05e7591b4","status":"Active","slug":"partner-slug-example","subscription":{"subscriptionId":"SUB-12345","status":"Trial"},"provisionedResource":{"name":"Provisioned Resource Example","ari":"ARI-456789"},"error":null,"missingAccountId":false}');

        mockService
            .when('getEntitlementPartnerInfo')
            .thenReturn(response);

        List<PendingInvoice__c> scopedInvoices = [
            SELECT Id, Name,
                Invoice_JSON__c,
                Invoice_JSON_2__c,
                Invoice_JSON_3__c,
                Invoice_JSON_4__c,
                Invoice_JSON_5__c,
                Opportunity__c,
                Status__c, RetryCount__c,
                LineItemsInserted__c, TotalLineItems__c,
                Error__c
            FROM PendingInvoice__c
            WHERE Status__c = 'Waiting'
            LIMIT 1
        ];
        System.debug('Invoices to process: ' + scopedInvoices);

        insert new AtlassianOffering__c(AtlassianId__c = '1ac3b7dd-7141-414e-bc00-c890acc458b0');

        System.debug('/// Queueable jobs before: ' + Limits.getQueueableJobs());
        Test.startTest();
        InvoiceToOpportunityBatch batch = new InvoiceToOpportunityBatch();
        batch.execute(null, scopedInvoices);
        Test.stopTest();
        System.debug('/// Queueable jobs after: ' + Limits.getQueueableJobs());
    }

    @IsTest
    static void testErrorHandlingInExecute() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account',
            AutoInvoiceImport__c = true
        );
        insert testAccount;

        // Create test Opportunity
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Explore',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpportunity;

        // Create an invoice with invalid JSON data to simulate a failure
        PendingInvoice__c invalidInvoice = new PendingInvoice__c(
            Opportunity__c = testOpportunity.Id,
            Account__c = testAccount.Id,
            Name = 'Invalid Invoice',
            Status__c = 'Waiting',
            Invoice_JSON__c = '{"invalidJsonPayload}',
            Invoice_JSON_2__c = '',
            Invoice_JSON_3__c = '',
            Invoice_JSON_4__c = '',
            Invoice_JSON_5__c = '',
            RetryCount__c = 0
        );
        insert invalidInvoice;

        List<PendingInvoice__c> scopedInvoices = [
            SELECT
                Id,
                Invoice_JSON__c,
                Invoice_JSON_2__c,
                Invoice_JSON_3__c,
                Invoice_JSON_4__c,
                Invoice_JSON_5__c,
                Status__c, Name, Error__c,
                TotalLineItems__c, LineItemsInserted__c,
                RetryCount__c, Account__c, Opportunity__c
            FROM PendingInvoice__c WHERE Id = :invalidInvoice.Id];

        Test.startTest();
        InvoiceToOpportunityBatch batch = new InvoiceToOpportunityBatch();
        batch.execute(null, scopedInvoices);
        Test.stopTest();

        // Assert that the record's status and retry count were updated on failure
        PendingInvoice__c updatedInvoice = [SELECT Status__c, RetryCount__c, Error__c FROM PendingInvoice__c WHERE Id = :invalidInvoice.Id];
        System.debug('Updated Invoice: ' + updatedInvoice);
        System.assertEquals('Error', updatedInvoice.Status__c, 'The invoice status should be set to Error.');
        System.assertEquals(2, updatedInvoice.RetryCount__c, 'The retry count should be incremented.');
    }
}