@IsTest
private class PromoCodeMatcherTest {

    /**
     * Realistic product names for testing
     *  - Index 0: Cloud + Standard
     *  - Index 1: Datacenter + Standard
     *  - Index 2: Cloud + Premium
     *  - Index 3: (reserved for future use)
     */
    private static final List<String> REALISTIC_PRODUCT_NAMES = new List<String>{
        'ScriptRunner for Jira Cloud Standard ANNUAL USD COMMERCIAL CLOUD',
        'Task Reminder – Slack & Mail Notifications for Confluence Standard ANNUAL USD COMMERCIAL DATACENTER',
        'Microsoft Intune Importer for JSM Assets Cloud Premium ANNUAL USD COMMERCIAL CLOUD',
        'Issue Templates for Jira Standard ANNUAL USD COMMERCIAL CLOUD'
    };

    /**
     * Helper to build a minimal QuoteInfo with one or more bill lines using
     * realistic product names. No Product2 mapping needed since we match directly
     * against quote line productName/description.
     */
    private static PortalCommerceApiQuotes.QuoteInfo buildQuoteInfo(List<String> productNames) {
        PortalCommerceApiQuotes.QuoteInfo quoteInfo = new PortalCommerceApiQuotes.QuoteInfo();
        quoteInfo.id = 'QUOTE-1';
        quoteInfo.version = 1;

        quoteInfo.upcomingBills = new PortalCommerceApiQuotes.BillItem();
        quoteInfo.upcomingBills.lines = new List<PortalCommerceApiQuotes.BillLineItem>();

        // Create quote lines with realistic product names
        for (Integer i = 0; i < productNames.size(); i++) {
            PortalCommerceApiQuotes.BillLineItem line = new PortalCommerceApiQuotes.BillLineItem();
            line.id = 'LINE-' + i;
            // Description and productName both use the realistic product name
            line.description = productNames[i];
            line.productName = productNames[i];
            quoteInfo.upcomingBills.lines.add(line);
        }

        return quoteInfo;
    }

    @IsTest
    static void testBasicMatchWithoutPlatformOrEdition() {
        // Build quote with realistic product names - use ScriptRunner twice to test deduplication
        List<String> productNames = new List<String>{
            REALISTIC_PRODUCT_NAMES[0], // ScriptRunner for Jira Cloud Standard...
            REALISTIC_PRODUCT_NAMES[0]  // Same product twice
        };
        PortalCommerceApiQuotes.QuoteInfo quoteInfo = buildQuoteInfo(productNames);

        // Promo code should match on 'ScriptRunner' in productName, no platform/edition filters
        PromotionCode__c promo = new PromotionCode__c(
            PromoCode__c    = 'SCRIPTRUNNER_PROMO',
            StartDate__c    = Date.today().addDays(-5),
            EndDate__c      = Date.today().addDays(5),
            Partner__c      = 'Test Partner',
            SearchString__c = 'ScriptRunner'
        );
        insert promo;

        Test.startTest();
        List<PromoCodeMatcher.PromoCodeMatch> matches =
            PromoCodeMatcher.getMatchingPromoCodes(JSON.serialize(quoteInfo));
        Test.stopTest();

        // We expect exactly one match even though there are two quote lines
        System.assertEquals(1, matches.size(), 'Should return one unique promo code match');
        System.assertEquals(promo.Id, matches[0].promoCode.Id, 'Returned promo code should be SCRIPTRUNNER_PROMO');
        System.assert(matches[0].matchedProductName.containsIgnoreCase('ScriptRunner'),
            'Matched product name should contain ScriptRunner');
    }

    @IsTest
    static void testPlatformAndEditionFiltersApplied() {
        // Build quote with realistic product name containing "Cloud" and "Standard"
        List<String> productNames = new List<String>{
            REALISTIC_PRODUCT_NAMES[0] // ScriptRunner for Jira Cloud Standard ANNUAL USD COMMERCIAL CLOUD
        };
        PortalCommerceApiQuotes.QuoteInfo quoteInfo = buildQuoteInfo(productNames);

        // Matching promo: Platform=Cloud, Edition=Standard (matches the product name)
        PromotionCode__c matchingPromo = new PromotionCode__c(
            PromoCode__c    = 'CLOUD_STANDARD',
            StartDate__c    = Date.today().addDays(-1),
            EndDate__c      = Date.today().addDays(10),
            Partner__c      = 'Test Partner',
            SearchString__c = 'ScriptRunner',
            Platform__c     = 'Cloud',
            Edition__c      = 'Standard'
        );

        // Non‑matching promo: Platform=Datacenter, Edition=Standard (Platform doesn't match)
        PromotionCode__c nonMatchingPromo = new PromotionCode__c(
            PromoCode__c    = 'DC_STANDARD',
            StartDate__c    = Date.today().addDays(-1),
            EndDate__c      = Date.today().addDays(10),
            Partner__c      = 'Test Partner',
            SearchString__c = 'ScriptRunner',
            Platform__c     = 'Datacenter',
            Edition__c      = 'Standard'
        );

        insert new List<PromotionCode__c>{ matchingPromo, nonMatchingPromo };

        Test.startTest();
        List<PromoCodeMatcher.PromoCodeMatch> matches =
            PromoCodeMatcher.getMatchingPromoCodes(JSON.serialize(quoteInfo));
        Test.stopTest();

        System.assertEquals(1, matches.size(),
            'Only the promo with matching Platform__c and Edition__c should be returned');
        System.assertEquals(matchingPromo.Id, matches[0].promoCode.Id,
            'Returned promo code should be CLOUD_STANDARD');
    }

    @IsTest
    static void testSinglePlatformOrEditionFilter() {
        // Build quote with:
        //  - Index 1: Datacenter + Standard
        //  - Index 2: Cloud + Premium
        List<String> productNames = new List<String>{
            REALISTIC_PRODUCT_NAMES[1],
            REALISTIC_PRODUCT_NAMES[2]
        };
        PortalCommerceApiQuotes.QuoteInfo quoteInfo = buildQuoteInfo(productNames);

        // Promo 1: filter only on Platform = Datacenter (should match index 1)
        PromotionCode__c dcOnlyPromo = new PromotionCode__c(
            PromoCode__c    = 'DC_ONLY',
            StartDate__c    = Date.today().addDays(-1),
            EndDate__c      = Date.today().addDays(10),
            Partner__c      = 'Test Partner',
            SearchString__c = 'Task Reminder',
            Platform__c     = 'Datacenter'
            // Edition__c left null on purpose
        );

        // Promo 2: filter only on Edition = Premium (should match index 2)
        PromotionCode__c premiumOnlyPromo = new PromotionCode__c(
            PromoCode__c    = 'PREMIUM_ONLY',
            StartDate__c    = Date.today().addDays(-1),
            EndDate__c      = Date.today().addDays(10),
            Partner__c      = 'Test Partner',
            SearchString__c = 'Microsoft Intune Importer',
            Edition__c      = 'Premium'
            // Platform__c left null on purpose
        );

        insert new List<PromotionCode__c>{ dcOnlyPromo, premiumOnlyPromo };

        Test.startTest();
        List<PromoCodeMatcher.PromoCodeMatch> matches =
            PromoCodeMatcher.getMatchingPromoCodes(JSON.serialize(quoteInfo));
        Test.stopTest();

        System.assertEquals(2, matches.size(),
            'Both single-filter promos (platform OR edition) should be returned');

        Set<Id> matchIds = new Set<Id>();
        for (PromoCodeMatcher.PromoCodeMatch m : matches) {
            matchIds.add(m.promoCode.Id);
        }
        System.assert(matchIds.contains(dcOnlyPromo.Id),
            'Result should include DC_ONLY promo (platform filter only)');
        System.assert(matchIds.contains(premiumOnlyPromo.Id),
            'Result should include PREMIUM_ONLY promo (edition filter only)');
    }

    @IsTest
    static void testNoActivePromoCodes() {
        // Build quote with realistic product names
        List<String> productNames = new List<String>{
            REALISTIC_PRODUCT_NAMES[0] // ScriptRunner for Jira Cloud Standard...
        };
        PortalCommerceApiQuotes.QuoteInfo quoteInfo = buildQuoteInfo(productNames);

        // Don't create any promo codes - should return empty list

        Test.startTest();
        List<PromoCodeMatcher.PromoCodeMatch> matches =
            PromoCodeMatcher.getMatchingPromoCodes(JSON.serialize(quoteInfo));
        Test.stopTest();

        System.assertEquals(0, matches.size(),
            'Should return empty list when no active promo codes exist');
    }

    @IsTest
    static void testEmptyQuoteString() {
        // Create an active promo code
        PromotionCode__c promo = new PromotionCode__c(
            PromoCode__c    = 'TEST_PROMO',
            StartDate__c    = Date.today().addDays(-5),
            EndDate__c      = Date.today().addDays(5),
            Partner__c      = 'Test Partner',
            SearchString__c = 'ScriptRunner'
        );
        insert promo;

        Test.startTest();
        // Test with null
        List<PromoCodeMatcher.PromoCodeMatch> matchesNull =
            PromoCodeMatcher.getMatchingPromoCodes(null);
        
        // Test with empty string
        List<PromoCodeMatcher.PromoCodeMatch> matchesEmpty =
            PromoCodeMatcher.getMatchingPromoCodes('');
        
        // Test with invalid JSON
        List<PromoCodeMatcher.PromoCodeMatch> matchesInvalid =
            PromoCodeMatcher.getMatchingPromoCodes('invalid json');
        Test.stopTest();

        System.assertEquals(0, matchesNull.size(),
            'Should return empty list when quote string is null');
        System.assertEquals(0, matchesEmpty.size(),
            'Should return empty list when quote string is empty');
        System.assertEquals(0, matchesInvalid.size(),
            'Should return empty list when quote string is invalid JSON');
    }
}