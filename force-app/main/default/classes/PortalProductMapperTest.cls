/**
 * Created by peterfriberg on 2024-06-25.
 */

@IsTest
private class PortalProductMapperTest {

    private static List<Product2> products;

    static void testSetup() {
        // Create a few Product2 records
        products = new List<Product2>();
        products.add(new Product2(Name = 'Atlassian Cloud - Marketplace Application', IsActive = true));
        products.add(new Product2(Name = 'Atlassian Data Center - Marketplace Application', IsActive = true));
        products.add(new Product2(Name = 'Atlassian Data Center - Confluence', IsActive = true));
        products.add(new Product2(Name = 'Atlassian Cloud - Premium - Jira Software', IsActive = true));
        products.add(new Product2(Name = 'Atlassian Cloud - Standard - Jira Software', IsActive = true));
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
    static void getInstance() {
        Test.startTest();
        PortalProductMapper mapper1 = PortalProductMapper.getInstance();
        PortalProductMapper mapper2 = PortalProductMapper.getInstance();
        Test.stopTest();

        System.assertNotEquals(null, mapper1, 'Instance 1 should not be null');
        System.assertNotEquals(null, mapper2, 'Instance 2 should not be null');
        System.assertEquals(mapper1, mapper2, 'Instances should be the same');
    }

    @IsTest
    static void testBasicMappingManyProductDefaultCloud() {
        testSetup();

        Test.startTest();
        PortalProductMapper mapper = PortalProductMapper.getInstance();
        PortalProductMapper.MappingResult result0 = mapper.mapProduct('Missing product', 'CLOUD', 'premium');
        PortalProductMapper.MappingResult result1 = mapper.mapProduct('Missing product', 'DATACENTER', 'premium');
        PortalProductMapper.MappingResult result2 = mapper.mapProduct('Confluence (Data Center)', 'DATACENTER', null);
        PortalProductMapper.MappingResult result3 = mapper.mapProduct('Jira (Cloud)', 'CLOUD', 'premium');
        PortalProductMapper.MappingResult result4 = mapper.mapProduct('Jira (Cloud)', 'CLOUD', 'standard');
        Test.stopTest();

        System.debug(result0);
        System.debug(result1);
        System.debug(result2);
        System.debug(result3);
        System.debug(result4);
        System.debug(products);
        System.assertEquals(products[0].Id, result0.product.Id, 'Product should be default cloud "Atlassian Cloud - Marketplace Application"');
        System.assertEquals(products[1].Id, result1.product.Id, 'Product should be default cloud "Atlassian Data Center - Marketplace Application"');
        System.assertEquals(products[2].Id, result2.product.Id, 'Product should be default cloud "Atlassian Data Center - Confluence"');
        System.assertEquals(products[3].Id, result3.product.Id, 'Product should be default cloud "Atlassian Cloud - Premium - Jira Software"');
        System.assertEquals(products[4].Id, result4.product.Id, 'Product should be default cloud "Atlassian Cloud - Standard - Jira Software"');
    }

    @IsTest
    static void testBasicMappingManyProductNoSfProducts() {
        Test.startTest();
        PortalProductMapper mapper = PortalProductMapper.getInstance();
        PortalProductMapper.MappingResult result0 = mapper.mapProduct('Missing product', 'CLOUD', 'premium');
        PortalProductMapper.MappingResult result1 = mapper.mapProduct('Missing product', 'DATACENTER', 'premium');
        PortalProductMapper.MappingResult result2 = mapper.mapProduct('Confluence (Data Center)', 'DATACENTER', null);
        PortalProductMapper.MappingResult result3 = mapper.mapProduct('Jira (Cloud)', 'CLOUD', 'premium');
        PortalProductMapper.MappingResult result4 = mapper.mapProduct('Jira (Cloud)', 'CLOUD', 'standard');
        PortalProductMapper.MappingResult result5 = mapper.mapProduct('Confluence (Data Center)', 'DATACENTER', 'premium');
        Test.stopTest();

        System.debug(result0);
        System.debug(result1);
        System.debug(result2);
        System.debug(result3);
        System.debug(result4);
        System.debug(result5);
        System.debug(products);
        System.assert(!result0.found, 'Product should not be found');
        System.assert(!result1.found, 'Product should not be found');
        System.assert(!result2.found, 'Product should not be found');
        System.assert(!result3.found, 'Product should not be found');
        System.assert(!result4.found, 'Product should not be found');
        System.assert(!result5.found, 'Product should not be found');
    }

    @IsTest
    static void testNameOnlyDefaultCloud() {
        testSetup();

        Test.startTest();
        PortalProductMapper mapper = PortalProductMapper.getInstance();
        PortalProductMapper.MappingResult result1 = mapper.mapProduct('Confluence (Data Center)', 'DATACENTER', 'premium');
        PortalProductMapper.MappingResult result2 = mapper.mapProduct('Bitbucket (Cloud)', 'DATACENTER', 'premium');
        Test.stopTest();

        System.debug(result1);
        System.debug(result2);
        System.assertEquals(products[1].Id, result1.product.Id, 'Product should be default cloud "Atlassian Data Center - Marketplace Application"');
        System.assertEquals(null, result2.product, 'Product should be null');
    }

    @IsTest
    static void testWrongAndMissing() {
        Test.startTest();
        PortalProductMapper mapper = PortalProductMapper.getInstance();
        PortalProductMapper.MappingResult result1 = mapper.mapProduct('Non existing', 'no platform', 'no edition');
        Test.stopTest();

        System.debug(result1);
        System.assertEquals(null, result1.product, 'Product should be null');
        System.assertEquals(false, result1.found, 'Product should not be found');
        System.assert(result1.info.containsIgnoreCase('platform unknown'), 'unknown platform');
        System.assert(result1.info.containsIgnoreCase('edition unknown'), 'unknown edition');
    }

}