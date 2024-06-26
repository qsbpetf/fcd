/**
 * Created by peterfriberg on 2024-06-25.
 */

@IsTest
private class  PortalQuoteConverterTest {

    private static final String FULL_JSON =
        '{\n' +
        '  "orderNumber" : "AT-315634773",\n' +
        '  "poNumber" : "123",\n' +
        '  "createdDate" : "2024-05-16T02:35:34.611-0500",\n' +
        '  "dueDate" : "2024-06-15T00:00:00.000-0500",\n' +
        '  "billingContact" : {\n' +
        '    "companyName" : "Eficode Finland",\n' +
        '    "firstName" : "Katja",\n' +
        '    "lastName" : "Loikkanen",\n' +
        '    "email" : "katja.loikkanen@eficode.com",\n' +
        '    "phone" : "+358405611299",\n' +
        '    "taxId" : "FI19718143",\n' +
        '    "address" : {\n' +
        '      "address1" : "Pohjoinen Rautatiekatu 25",\n' +
        '      "address2" : "",\n' +
        '      "city" : "Helsinki",\n' +
        '      "postalCode" : "00100",\n' +
        '      "state" : "Uusimaa",\n' +
        '      "country" : "Finland"\n' +
        '    }\n' +
        '  },\n' +
        '  "technicalContact" : {\n' +
        '    "companyName" : "Eficode",\n' +
        '    "firstName" : "Antti",\n' +
        '    "lastName" : "Päivinen",\n' +
        '    "email" : "antti.paivinen@eficode.com",\n' +
        '    "phone" : "358447736646",\n' +
        '    "taxId" : "",\n' +
        '    "address" : {\n' +
        '      "address1" : "Pohjoinen Rautatiekatu 25",\n' +
        '      "address2" : "",\n' +
        '      "city" : "Helsinki",\n' +
        '      "postalCode" : "00100",\n' +
        '      "state" : "Uusimaa",\n' +
        '      "country" : "Finland"\n' +
        '    }\n' +
        '  },\n' +
        '  "currency" : "USD",\n' +
        '  "partnerName" : "Eficode Finland",\n' +
        '  "orderItems" : [ {\n' +
        '    "productName" : "Bitbucket (Cloud)",\n' +
        '    "startDate" : "2024-05-03T00:00:00.000-0500",\n' +
        '    "endDate" : "2025-05-03T00:00:00.000-0500",\n' +
        '    "licensedTo" : "Eficode",\n' +
        '    "description" : "Bitbucket (Cloud) 50 Users (Annual Payments) Renewal",\n' +
        '    "edition" : "premium",\n' +
        '    "cloudSiteHostname" : "groke-tech",\n' +
        '    "supportEntitlementNumber" : "SEN-42318436",\n' +
        '    "entitlementNumber" : "E-3Z4-J85-263-SR4",\n' +
        '    "entitlementId" : "b692f44e-e01a-470d-b7cc-61c49f4ac015",\n' +
        '    "saleType" : "RENEWAL",\n' +
        '    "unitPrice" : 3000.00,\n' +
        '    "platform" : "CLOUD",\n' +
        '    "taxExempt" : false,\n' +
        '    "licenseType" : "COMMERCIAL",\n' +
        '    "unitCount" : 50,\n' +
        '    "isTrialPeriod" : false,\n' +
        '    "isUnlimitedUsers" : false,\n' +
        '    "maintenanceMonths" : 12,\n' +
        '    "priceAdjustment" : 300.00,\n' +
        '    "upgradeCredit" : 0.00,\n' +
        '    "partnerDiscountTotal" : 300.00,\n' +
        '    "loyaltyDiscountTotal" : 0,\n' +
        '    "discounts" : [ {\n' +
        '      "amount" : 300.00,\n' +
        '      "percentage" : 10.00,\n' +
        '      "reason" : "PARTNER_DISCOUNT",\n' +
        '      "type" : "EXPERT"\n' +
        '    } ],\n' +
        '    "total" : 2700.00\n' +
        '  }, \n' +
        '  {\n' +
        '    "productName" : "Bitbucket (Data Center)",\n' +
        '    "startDate" : null,\n' +
        '    "endDate" : null,\n' +
        '    "licensedTo" : "Eficode",\n' +
        '    "description" : "Bitbucket (Data Center)",\n' +
        '    "edition" : null,\n' +
        '    "cloudSiteHostname" : "groke-tech",\n' +
        '    "supportEntitlementNumber" : "SEN-42318436",\n' +
        '    "entitlementNumber" : "E-3Z4-J85-263-SR4",\n' +
        '    "entitlementId" : "b692f44e-e01a-470d-b7cc-61c49f4ac015",\n' +
        '    "saleType" : "NEW",\n' +
        '    "unitPrice" : 3000.00,\n' +
        '    "platform" : "DATACENTER",\n' +
        '    "taxExempt" : false,\n' +
        '    "licenseType" : "COMMERCIAL",\n' +
        '    "unitCount" : 50,\n' +
        '    "isTrialPeriod" : false,\n' +
        '    "isUnlimitedUsers" : false,\n' +
        '    "maintenanceMonths" : 12,\n' +
        '    "priceAdjustment" : 300.00,\n' +
        '    "upgradeCredit" : 0.00,\n' +
        '    "partnerDiscountTotal" : 300.00,\n' +
        '    "loyaltyDiscountTotal" : 0,\n' +
        '    "discounts" : [ {\n' +
        '      "amount" : 300.00,\n' +
        '      "percentage" : 10.00,\n' +
        '      "reason" : "PARTNER_DISCOUNT",\n' +
        '      "type" : "EXPERT"\n' +
        '    } ],\n' +
        '    "total" : 2700.00\n' +
        '  } ],\n' +
        '  "totalExTax" : 2700.00,\n' +
        '  "totalIncTax" : 2700.00,\n' +
        '  "totalTax" : 0.00\n' +
        '}';

    private static List<Product2> products;

    static void testSetup() {
        // Create a few Product2 records
        products = new List<Product2>();
        products.add(new Product2(Name = 'Atlassian Cloud - Marketplace Application', IsActive = true));
        products.add(new Product2(Name = 'Atlassian Data Center - Marketplace Application', IsActive = true));
        products.add(new Product2(Name = 'Atlassian Data Center - Bitbucket', IsActive = true));
        products.add(new Product2(Name = 'Atlassian Cloud - Premium - Jira Software', IsActive = true));
        products.add(new Product2(Name = 'Atlassian Cloud - Premium - Bitbucket', IsActive = true));
        insert products;

        // Get test pricebook
        Id standardPricebookId = Test.getStandardPricebookId();

        // Create a few PricebookEntry records
        List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
        pricebookEntries.add(new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = products[0].Id, UnitPrice = 100.00, IsActive = true, CurrencyIsoCode = 'USD'));
        pricebookEntries.add(new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = products[1].Id, UnitPrice = 200.00, IsActive = true, CurrencyIsoCode = 'USD'));
        pricebookEntries.add(new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = products[2].Id, UnitPrice = 300.00, IsActive = true, CurrencyIsoCode = 'USD'));
        pricebookEntries.add(new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = products[3].Id, UnitPrice = 400.00, IsActive = true, CurrencyIsoCode = 'USD'));
        pricebookEntries.add(new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = products[4].Id, UnitPrice = 500.00, IsActive = true, CurrencyIsoCode = 'USD'));
        insert pricebookEntries;
    }

    @IsTest
    static void validateGetJsonFile(){

        ContentVersion cv = new ContentVersion(
            Title = 'TestCV',
            PathOnClient = 'TestCV.jpg',
            VersionData = Blob.valueOf('Test Content')
        );
        insert cv;
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        opp.Pricebook2Id = Test.getStandardPricebookId();
        insert opp;

        Test.startTest();
        String fileContent = PortalQuoteConverter.getJsonFile(cv.Id, cv.Id, cv.ContentDocumentId, opp.Id);
        Test.stopTest();

        System.assertEquals('Test Content', fileContent, 'File contents must be correct');

        List<ContentVersion> cvList = new List<ContentVersion>([SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id]);
        List<ContentDocument> cdList = new List<ContentDocument>([SELECT Id FROM ContentDocument WHERE Id = :cv.ContentDocumentId]);
        System.assertEquals(0, cvList.size(), 'ContentVersion must be deleted');
        System.assertEquals(0, cdList.size(), 'ContentDocument must be deleted');
    }

    @IsTest
    static void validateParseJson() {
        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        insert opp;

        String jsonText = '{"orderNumber": "ABC123"}';

        Test.startTest();
        PortalJsonParser.OrderInformation orderInfo = PortalQuoteConverter.parseJson(jsonText);
        Test.stopTest();

        System.assertEquals('ABC123', orderInfo.orderNumber, 'Order number must be set');
        System.assertEquals(0, orderInfo.orderItems.size(), 'Order items must be empty');
    }

    @IsTest
    private static void testGetLatestCurrencyConversionFactor() {
        Buying_Exchange_Rate__c buying_Exchange_Rate_Old = new Buying_Exchange_Rate__c(
            Exchange_Rate_from_USD_to_EUR__c = 0.80,
            Exchange_Rate_from_USD_to_GBP__c = 0.70,
            Start_Date__c = Date.today().addDays(-1)
        );
        Buying_Exchange_Rate__c buying_Exchange_Rate_New = new Buying_Exchange_Rate__c(
            Exchange_Rate_from_USD_to_EUR__c = 0.83,
            Exchange_Rate_from_USD_to_GBP__c = 0.75,
            Start_Date__c = Date.today()
        );
        insert new List<Buying_Exchange_Rate__c> { buying_Exchange_Rate_Old, buying_Exchange_Rate_New };

        // Test getLatestCurrencyConversionFactor method when currency is EUR
        Test.startTest();
        Double eurConversionRate = PortalQuoteConverter.getLatestCurrencyConversionFactor('EUR');
        Double gbpConversionRate = PortalQuoteConverter.getLatestCurrencyConversionFactor('GBP');
        Double yenConversionRate = PortalQuoteConverter.getLatestCurrencyConversionFactor('YEN');
        Test.stopTest();

        // Assert the results
        System.assertEquals(0.83, eurConversionRate, 'Conversion rate must be correct');
        System.assertEquals(0.75, gbpConversionRate, 'Conversion rate must be correct');
        System.assertEquals(1.00, yenConversionRate, 'Conversion rate must be correct');
    }

    @IsTest
    private static void testMissingCurrencyConversionFactor() {
        Test.startTest();
        Double missingConversionRate = PortalQuoteConverter.getLatestCurrencyConversionFactor('EUR');
        Test.stopTest();

        // Assert the results
        System.assertEquals(1.00, missingConversionRate, 'Conversion rate must be correct');
    }

    @IsTest
    private static void testGetOpportunity() {
        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Contact con = TestDataFactory.getCon(acc.Id);
        con.Email = 'abc@example.com';
        insert con;

        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        opp.Atlassian_AT_Quote_ref__c = 'QR-123';
        opp.Atlassian_AT_Quote_amount__c = 123.0;
        opp.Atlassian_AT_Quote_Tech_Contact__c = con.Id;
        opp.AT_quote_expiry__c = Date.today();
        opp.QuoteImportResult__c = 'Success';
        insert opp;

        // Test getOpportunity method
        Test.startTest();
        Opportunity opportunity = PortalQuoteConverter.getOpportunity(opp.Id);
        Test.stopTest();

        // Assert the results
        System.assertEquals(opp.Id, opportunity.Id, 'Opportunity must be correct');
    }

    @IsTest
    private static void testUpdateOpportunityContactCreated() {
        // Prepare test data
        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        insert opp;

        PortalJsonParser.OrderInformation orderInfo = new PortalJsonParser.OrderInformation();
        orderInfo.orderNumber = 'QR-123';
        orderInfo.totalExTax = 123.0;
        orderInfo.dueDate = Date.today();
        orderInfo.technicalContact = new PortalJsonParser.TechnicalContactDetails();
        orderInfo.technicalContact.email = 'hej@example.com';
        orderInfo.technicalContact.firstName = 'John';
        orderInfo.technicalContact.lastName = 'Doe';

        OpportunityProductMapper.LogData log = new OpportunityProductMapper.LogData();
        log.productLog.add('One');
        log.pbeLog.add('Two');

        // Test updateOpportunity method
        Test.startTest();
        PortalQuoteConverter.updateOpportunity(opp, orderInfo, log);
        Test.stopTest();

        // Assert the results
        Opportunity opportunity = [SELECT Id, Atlassian_AT_Quote_ref__c, Atlassian_AT_Quote_amount__c, Atlassian_AT_Quote_Tech_Contact__c, AT_quote_expiry__c, QuoteImportResult__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('QR-123', opportunity.Atlassian_AT_Quote_ref__c, 'Opportunity must be correct');
        System.assertEquals(123.0, opportunity.Atlassian_AT_Quote_amount__c, 'Opportunity must be correct');
        System.assertNotEquals(null, opportunity.Atlassian_AT_Quote_Tech_Contact__c, 'Opportunity must be correct');
        System.assertEquals(Date.today(), opportunity.AT_quote_expiry__c, 'Opportunity must be correct');
        System.assert(opportunity.QuoteImportResult__c.containsIgnoreCase('One'), 'Opportunity must be correct');
        System.assert(opportunity.QuoteImportResult__c.containsIgnoreCase('Two'), 'Opportunity must be correct');
    }

    @IsTest
    private static void testUpdateOpportunityExistingContact() {
        // Prepare test data
        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Contact con = TestDataFactory.getCon(acc.Id);
        con.Email = 'hej@example.com';
        con.FirstName = 'John';
        con.LastName = 'Doe';
        insert con;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        insert opp;

        PortalJsonParser.OrderInformation orderInfo = new PortalJsonParser.OrderInformation();
        orderInfo.orderNumber = 'QR-123';
        orderInfo.totalExTax = 123.0;
        orderInfo.dueDate = Date.today();
        orderInfo.technicalContact = new PortalJsonParser.TechnicalContactDetails();
        orderInfo.technicalContact.email = 'hej@example.com';
        orderInfo.technicalContact.firstName = 'John';
        orderInfo.technicalContact.lastName = 'Doe';

        OpportunityProductMapper.LogData log = new OpportunityProductMapper.LogData();
        log.productLog.add('One');
        log.pbeLog.add('Two');

        // Test updateOpportunity method
        Test.startTest();
        PortalQuoteConverter.updateOpportunity(opp, orderInfo, log);
        Test.stopTest();

        // Assert the results
        Opportunity opportunity = [SELECT Id, Atlassian_AT_Quote_ref__c, Atlassian_AT_Quote_amount__c, Atlassian_AT_Quote_Tech_Contact__c, AT_quote_expiry__c, QuoteImportResult__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('QR-123', opportunity.Atlassian_AT_Quote_ref__c, 'Opportunity must be correct');
        System.assertEquals(123.0, opportunity.Atlassian_AT_Quote_amount__c, 'Opportunity must be correct');
        System.assertNotEquals(null, opportunity.Atlassian_AT_Quote_Tech_Contact__c, 'Opportunity must be correct');
        System.assertEquals(Date.today(), opportunity.AT_quote_expiry__c, 'Opportunity must be correct');
        System.assert(opportunity.QuoteImportResult__c.containsIgnoreCase('One'), 'Opportunity must be correct');
        System.assert(opportunity.QuoteImportResult__c.containsIgnoreCase('Two'), 'Opportunity must be correct');

        List<Contact> conList = new List<Contact>([SELECT Id, Email, FirstName, LastName FROM Contact]);
        System.assertEquals(1, conList.size(), 'No new Contact created');
        System.assertEquals('John', conList[0].FirstName, 'Contact must be correct');
        System.assertEquals('Doe', conList[0].LastName, 'Contact must be correct');
        System.assertEquals('hej@example.com', conList[0].Email, 'Contact must be correct');
    }

    @IsTest
    private static void testUpdateOpportunityContactStateFailedSetToNull() {
        // Prepare test data
        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        insert opp;

        PortalJsonParser.OrderInformation orderInfo = new PortalJsonParser.OrderInformation();
        orderInfo.orderNumber = 'QR-123';
        orderInfo.totalExTax = 123.0;
        orderInfo.dueDate = Date.today();
        orderInfo.technicalContact = new PortalJsonParser.TechnicalContactDetails();
        orderInfo.technicalContact.email = 'hej@example.com';
        orderInfo.technicalContact.firstName = 'John';
        orderInfo.technicalContact.lastName = 'Doe';
        orderInfo.technicalContact.address.address1 = 'street';
        orderInfo.technicalContact.address.city = 'Helsinki';
        orderInfo.technicalContact.address.state = 'Failed State';
        orderInfo.technicalContact.address.postalCode = '12345';
        orderInfo.technicalContact.address.country = 'Finland';

        OpportunityProductMapper.LogData log = new OpportunityProductMapper.LogData();
        log.productLog.add('One');
        log.pbeLog.add('Two');

        // Test updateOpportunity method
        Test.startTest();
        PortalQuoteConverter.updateOpportunity(opp, orderInfo, log);
        Test.stopTest();

        // Assert the results
        Opportunity opportunity = [SELECT Id, Atlassian_AT_Quote_ref__c, Atlassian_AT_Quote_amount__c, Atlassian_AT_Quote_Tech_Contact__c, AT_quote_expiry__c, QuoteImportResult__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('QR-123', opportunity.Atlassian_AT_Quote_ref__c, 'Opportunity must be correct');
        System.assertEquals(123.0, opportunity.Atlassian_AT_Quote_amount__c, 'Opportunity must be correct');
        System.assertNotEquals(null, opportunity.Atlassian_AT_Quote_Tech_Contact__c, 'Opportunity must be correct');
        System.assertEquals(Date.today(), opportunity.AT_quote_expiry__c, 'Opportunity must be correct');
        System.assert(opportunity.QuoteImportResult__c.containsIgnoreCase('One'), 'Opportunity must be correct');
        System.assert(opportunity.QuoteImportResult__c.containsIgnoreCase('Two'), 'Opportunity must be correct');

        List<Contact> conList = new List<Contact>([SELECT Id, Email, FirstName, LastName, MailingStreet, MailingPostalCode, MailingCity, MailingState, MailingCountry FROM Contact]);
        System.assertEquals(1, conList.size(), 'New Contact created');
        System.assertEquals('John', conList[0].FirstName, 'Contact must be correct');
        System.assertEquals('Doe', conList[0].LastName, 'Contact must be correct');
        System.assertEquals('hej@example.com', conList[0].Email, 'Contact must be correct');
        System.assertEquals('street', conList[0].MailingStreet, 'Contact must be correct');
        System.assertEquals(null, conList[0].MailingState, 'Contact must be correct');
        System.assertEquals('Helsinki', conList[0].MailingCity, 'Contact must be correct');
        System.assertEquals('12345', conList[0].MailingPostalCode, 'Contact must be correct');
        System.assertEquals('Finland', conList[0].MailingCountry, 'Contact must be correct');
    }

    @IsTest
    private static void testConvertQuoteToOpptyAndLineItemsOk() {
        testSetup();

        Account acc = TestDataFactory.getAccount('Sweden', 'USD');
        insert acc;
        Opportunity opp = TestDataFactory.getOpp(acc.Id, 'USD');
        opp.Pricebook2Id = Test.getStandardPricebookId();
        insert opp;

        Test.startTest();
        OpportunityProductMapper.LogData log = PortalQuoteConverter.convertQuote(FULL_JSON, opp.Id, true);
        Test.stopTest();

        List<OpportunityLineItem> oliList = new List<OpportunityLineItem>([SELECT Id FROM OpportunityLineItem]);
        System.assertEquals(2, oliList.size(), 'Opportunity Line Items must be created');

        List<Contact> conList = new List<Contact>([SELECT Id FROM Contact]);
        System.assertEquals(1, conList.size(), 'New Contact created');
    }
}