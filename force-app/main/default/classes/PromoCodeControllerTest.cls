@IsTest
private class PromoCodeControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test promo codes
        List<PromotionCode__c> promoCodes = new List<PromotionCode__c>();

        // Active promo codes with different partners
        promoCodes.add(new PromotionCode__c(
            PromoCode__c = 'SUMMER2024',
            StartDate__c = Date.today().addDays(-10),
            EndDate__c = Date.today().addDays(20),
            Partner__c = 'Acme Corporation'
        ));

        promoCodes.add(new PromotionCode__c(
            PromoCode__c = 'WINTER2024',
            StartDate__c = Date.today().addDays(-5),
            EndDate__c = Date.today().addDays(30),
            Partner__c = 'Global Solutions'
        ));

        promoCodes.add(new PromotionCode__c(
            PromoCode__c = 'ACME50',
            StartDate__c = Date.today().addDays(-15),
            EndDate__c = Date.today().addDays(15),
            Partner__c = 'Acme Corporation'
        ));

        // Inactive promo code (should not be returned)
        promoCodes.add(new PromotionCode__c(
            PromoCode__c = 'EXPIRED2023',
            StartDate__c = Date.today().addDays(-100),
            EndDate__c = Date.today().addDays(-50),
            Partner__c = 'Old Partner'
        ));

        // Active promo code with null partner
        promoCodes.add(new PromotionCode__c(
            PromoCode__c = 'NOPARTNER',
            StartDate__c = Date.today(),
            EndDate__c = Date.today().addDays(10),
            Partner__c = null
        ));

        insert promoCodes;
    }

    @IsTest
    static void testGetAllActivePromoCodes() {
        // Test retrieving all active promo codes without partner filter
        Test.startTest();
        List<PromotionCode__c> results = PromoCodeController.getActivePromoCodes(null);
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(4, results.size(), 'Should return 4 active promo codes');

        // Verify inactive codes are not included
        for (PromotionCode__c promo : results) {
            System.assertEquals(true, promo.IsActive__c, 'All returned codes should be active');
            System.assertNotEquals('EXPIRED2023', promo.PromoCode__c, 'Inactive promo should not be returned');
        }
    }

    @IsTest
    static void testGetActivePromoCodesWithPartnerFilter() {
        // Test retrieving promo codes filtered by partner name
        Test.startTest();
        List<PromotionCode__c> results = PromoCodeController.getActivePromoCodes('Acme');
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(2, results.size(), 'Should return 2 promo codes for Acme Corporation');

        // Verify all returned codes contain the search term
        for (PromotionCode__c promo : results) {
            System.assert(promo.Partner__c.containsIgnoreCase('Acme'),
                'Partner name should contain search term');
            System.assertEquals(true, promo.IsActive__c, 'All returned codes should be active');
        }
    }

    @IsTest
    static void testGetActivePromoCodesWithEmptyString() {
        // Test with empty string (should return all active promo codes)
        Test.startTest();
        List<PromotionCode__c> results = PromoCodeController.getActivePromoCodes('');
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(4, results.size(), 'Empty string should return all active promo codes');
    }

    @IsTest
    static void testGetActivePromoCodesWithNoMatches() {
        // Test with partner name that doesn't exist
        Test.startTest();
        List<PromotionCode__c> results = PromoCodeController.getActivePromoCodes('NonExistentPartner');
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(0, results.size(), 'Should return empty list when no matches found');
    }

    @IsTest
    static void testGetActivePromoCodesWithPartialMatch() {
        // Test with partial partner name
        Test.startTest();
        List<PromotionCode__c> results = PromoCodeController.getActivePromoCodes('Global');
        Test.stopTest();

        // Verify results
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(1, results.size(), 'Should return 1 promo code for Global Solutions');
        System.assertEquals('WINTER2024', results[0].PromoCode__c, 'Should return correct promo code');
        System.assertEquals('Global Solutions', results[0].Partner__c, 'Should match partner name');
    }

    @IsTest
    static void testGetActivePromoCodesCaseInsensitive() {
        // Test case insensitivity of partner search
        Test.startTest();
        List<PromotionCode__c> resultsLower = PromoCodeController.getActivePromoCodes('acme');
        List<PromotionCode__c> resultsUpper = PromoCodeController.getActivePromoCodes('ACME');
        Test.stopTest();

        // Verify both queries return same results
        System.assertEquals(resultsLower.size(), resultsUpper.size(),
            'Case insensitive search should return same number of results');
        System.assertEquals(2, resultsLower.size(), 'Should return 2 promo codes regardless of case');
    }

    @IsTest
    static void testGetActivePromoCodesFieldsReturned() {
        // Test that all required fields are returned
        Test.startTest();
        List<PromotionCode__c> results = PromoCodeController.getActivePromoCodes(null);
        Test.stopTest();

        // Verify all required fields are populated
        System.assert(results.size() > 0, 'Should have results to test');

        PromotionCode__c firstResult = results[0];
        System.assertNotEquals(null, firstResult.Id, 'Id field should be populated');
        System.assertNotEquals(null, firstResult.PromoCode__c, 'PromoCode__c field should be populated');
        System.assertNotEquals(null, firstResult.StartDate__c, 'StartDate__c field should be populated');
        System.assertNotEquals(null, firstResult.EndDate__c, 'EndDate__c field should be populated');
    }

    @IsTest
    static void testGetActivePromoCodesOrdering() {
        // Test that results are ordered by StartDate__c DESC
        Test.startTest();
        List<PromotionCode__c> results = PromoCodeController.getActivePromoCodes(null);
        Test.stopTest();

        // Verify ordering
        System.assert(results.size() >= 2, 'Need at least 2 results to test ordering');

        for (Integer i = 0; i < results.size() - 1; i++) {
            System.assert(results[i].StartDate__c >= results[i + 1].StartDate__c,
                'Results should be ordered by StartDate__c DESC');
        }
    }

    @IsTest
    static void testBulkPromoCodeRetrieval() {
        // Test with larger data set (create additional records)
        List<PromotionCode__c> bulkPromoCodes = new List<PromotionCode__c>();

        for (Integer i = 0; i < 200; i++) {
            bulkPromoCodes.add(new PromotionCode__c(
                PromoCode__c = 'BULK' + i,
                StartDate__c = Date.today().addDays(-i),
                EndDate__c = Date.today().addDays(i),
                Partner__c = 'Bulk Partner ' + Math.mod(i, 10)
            ));
        }

        insert bulkPromoCodes;

        // Test retrieval
        Test.startTest();
        List<PromotionCode__c> results = PromoCodeController.getActivePromoCodes(null);
        Test.stopTest();

        // Verify bulk operation succeeds
        System.assert(results.size() >= 200, 'Should handle bulk records efficiently');
    }
}