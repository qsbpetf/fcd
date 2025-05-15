/**
 * Created by peterfriberg on 2025-05-04.
 */

@IsTest
private class PpcInvoiceImporterBatchTest {

    private static final UniversalMocker mockService;
    private static final PortalCommerceApiInvoices mockServiceStub;

    static {
        mockService = UniversalMocker.mock(PortalCommerceApiInvoices.class);
        mockServiceStub = (PortalCommerceApiInvoices) mockService.createStub();
        PortalCommerceApiInvoices.instance = new PortalCommerceApiInvoices();
        PortalCommerceApiController.setApiInvoices(mockServiceStub);
    }

    private static final String CRON_EXPR = '0 0 0 * * ?'; // Midnight every day

    @TestSetup
    static void setupTestData() {
        // Create test data if needed
        Account testAccount = new Account(
            Name = 'Test Account',
            AutoInvoiceImport__c = true,
            CV_Subsidiary__c = 'FI',
            BillingCountry = 'Finland'
        );
        insert testAccount;
    }

    @IsTest
    static void testSchedulerExecute() {
        Test.startTest();

        // Create and execute the scheduler
        PpcInvoiceImporterBatch scheduler = new PpcInvoiceImporterBatch();

        // Execute the scheduler
        scheduler.execute(null);

        Test.stopTest();
    }

    @IsTest
    static void testScheduleJob() {
        Test.startTest();

        // Replace the original static method with our mock
        PpcInvoiceImporterBatch scheduler = new PpcInvoiceImporterBatch();

        // Schedule the job
        String jobId = System.schedule(
            'Test PpcInvoiceImporterBatch Job',
            CRON_EXPR,
            scheduler
        );

        // Verify that the job was scheduled
        CronTrigger cronTrigger = [SELECT Id, CronExpression, TimesTriggered, NextFireTime
                                  FROM CronTrigger
                                  WHERE Id = :jobId];

        System.assertEquals(CRON_EXPR, cronTrigger.CronExpression, 'Cron expression should match');
        System.assertEquals(0, cronTrigger.TimesTriggered, 'Job should not have been triggered yet');
        System.assertNotEquals(null, cronTrigger.NextFireTime, 'Next fire time should be set');

        Test.stopTest();
    }

    @IsTest
    static void testBatchJobExecution() {
        Test.startTest();

        // Replace the original static method with our mock
        // Create and execute scheduler
        PpcInvoiceImporterBatch sched = new PpcInvoiceImporterBatch();
        sched.execute(null);

        Test.stopTest();
    }

    @IsTest
    static void testBatchJobExecutionWithMock() {
        PortalCommerceApiInvoices.InvoiceList invoices = new PortalCommerceApiInvoices.InvoiceList();

        // Create a new InvoiceInfo object with sample data
        PortalCommerceApiInvoices.InvoiceInfo testInvoice = new PortalCommerceApiInvoices.InvoiceInfo();
        testInvoice.id = 'INV-123456789';
        testInvoice.status = 'PAID';
        testInvoice.invoiceNumber = 'IN-2025-0001';
        testInvoice.additionalNotes = 'This is a test invoice with sample data';
        testInvoice.isoCurrency = 'EUR';
        testInvoice.total = 1250.50;
        testInvoice.subTotal = 1150.00;
        testInvoice.tax = 100.50;
        testInvoice.createdAt = System.currentTimeMillis() - (7 * 24 * 60 * 60 * 1000); // 7 days ago
        testInvoice.dueAt = System.currentTimeMillis() + (14 * 24 * 60 * 60 * 1000);    // 14 days in the future
        testInvoice.paidAt = System.currentTimeMillis() - (2 * 24 * 60 * 60 * 1000);    // 2 days ago
        testInvoice.office = 'FI';
        testInvoice.paymentMethodObj = new PortalCommerceApiInvoices.PaymentMethodObjType();
        testInvoice.paymentMethodObj.type = 'CARD';

        PortalCommerceApiInvoices.InvoiceItem testItem = new PortalCommerceApiInvoices.InvoiceItem();
        testItem.description = 'Guard, Monthly, Standard (USD, Default, 16-10-2024)';
        testItem.quantity = 1;
        testItem.total = 1250.50;
        testItem.subTotal = 1150.00;
        testItem.tax = 100.50;
        testItem.id = 'ITEM-123456789';
        testItem.planObj = new PortalCommerceApiInvoices.PlanObjectInfo();
        testItem.planObj.cycle = new PortalCommerceApiInvoices.CycleType();
        testItem.planObj.cycle.interval = 'MONTHLY';

        testInvoice.items = new List<PortalCommerceApiInvoices.InvoiceItem>();
        testInvoice.items.add(testItem);

        invoices.data = new List<PortalCommerceApiInvoices.InvoiceInfo>();
        invoices.data.add(testInvoice);

        mockService
            .when('getPaidInvoices')
            .thenReturn(invoices);

        insert new PPC_InvoiceAutoImportSettings__c(
            Name = 'Default',
            AutomationEnabled__c = true,
            LastDays__c = 30,
            DaysToKeepPendingInvoices__c = 20,
            DeletePendingInvoices__c = true
        );

        insert new InvoiceGroup__c(
            Name = 'Default',
            Account__c = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1].Id,
            AtlassianInvoiceGroupId__c = '123456789',
            Active__c = true,
            CreatedAt__c = System.now()
        );

        Product2 prod = TestDataFactory.getProduct();
        System.debug(prod);
        prod.Name = 'Atlassian Cloud - Standard - Atlassian Guard';
        insert prod;

        PricebookEntry pbe1 = TestDataFactory.getPbEntry(Test.getStandardPricebookId(), prod.Id, 'CHF');
        PricebookEntry pbe2 = TestDataFactory.getPbEntry(Test.getStandardPricebookId(), prod.Id, 'USD');
        PricebookEntry pbe3 = TestDataFactory.getPbEntry(Test.getStandardPricebookId(), prod.Id, 'EUR');
        insert new List<PricebookEntry>{ pbe1, pbe2, pbe3 };

        Test.startTest();
        PpcInvoiceImporterBatch.run(30);
        Test.stopTest();
    }
}