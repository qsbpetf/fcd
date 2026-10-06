@IsTest
private class QuotePdfTest {

    // If org validation rules or required fields block these inserts, add the missing values here.
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Demo Customer Oy');
        insert acc;

        List<Product2> products = new List<Product2>{
            new Product2(Name = 'Jira Cloud Premium', Family = 'LIC: Atlassian: Cloud: Core', IsActive = true),
            new Product2(Name = 'Managed Jira Service', Family = 'MS: Application Support', IsActive = true),
            new Product2(Name = 'GitLab Ultimate', Family = 'LIC: GitLab', IsActive = true),
            new Product2(Name = 'DevOps Consulting Day', Family = 'CON: Consulting', IsActive = true),
            // product-level setting wins over the family mapping
            new Product2(Name = 'Marketplace App', Family = 'LIC: Atlassian: Cloud: Core', Quote_Terms_Group__c = 'Other_License', IsActive = true)
        };
        insert products;

        Id pbId = Test.getStandardPricebookId();
        List<PricebookEntry> entries = new List<PricebookEntry>();
        for (Product2 p : products) {
            entries.add(new PricebookEntry(Pricebook2Id = pbId, Product2Id = p.Id, UnitPrice = 1000, IsActive = true));
        }
        insert entries;

        insert new Opportunity(
            Name = 'Demo Opp', AccountId = acc.Id, Pricebook2Id = pbId, CloseDate = Date.today().addDays(30),
            StageName = Opportunity.StageName.getDescribe().getPicklistValues()[0].getValue()
        );
    }

    // ------------------------------------------------------------------------------- helpers
    private static Quote newQuote(String variant) {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity LIMIT 1];
        Quote q = new Quote(Name = 'Demo Quote', OpportunityId = opp.Id, Pricebook2Id = opp.Pricebook2Id,
            ExpirationDate = Date.today().addDays(14), Template_Variant__c = variant);
        insert q;
        return q;
    }

    private static void addProducts(Quote q, List<String> productNames) {
        List<QuoteLineItem> items = new List<QuoteLineItem>();
        for (PricebookEntry pbe : [SELECT Id, UnitPrice FROM PricebookEntry
                                   WHERE Pricebook2Id = :q.Pricebook2Id AND Product2.Name IN :productNames]) {
            items.add(new QuoteLineItem(QuoteId = q.Id, PricebookEntryId = pbe.Id, Quantity = 2,
                UnitPrice = pbe.UnitPrice, ServiceDate = Date.today()));
        }
        insert items;
    }

    private static Set<String> codes(QuoteTermsResolver.Resolution r) {
        Set<String> out = new Set<String>();
        for (QuoteTermsResolver.ModuleView m : r.modules) out.add(m.code);
        return out;
    }

    private static String storedTerms(Id quoteId) {
        return [SELECT Terms_And_Conditions__c FROM Quote WHERE Id = :quoteId].Terms_And_Conditions__c;
    }

    private static Integer occurrences(String haystack, String needle) {
        return haystack == null ? 0 : haystack.countMatches(needle);
    }

    // --------------------------------------------------------------------------------- tests
    @IsTest
    static void licenceAndManagedServiceBothBringTheirTerms() {
        Quote q = newQuote('Global');
        Test.startTest();
        addProducts(q, new List<String>{ 'Jira Cloud Premium', 'Managed Jira Service' });
        Test.stopTest();

        QuoteTermsResolver.Resolution r = QuoteTermsResolver.resolve(q.Id, null);
        Assert.areEqual('Non-binding', r.offerType, 'managed services make the offer non-binding');
        Assert.isTrue(codes(r).contains('LICENSE'));
        Assert.isTrue(codes(r).contains('MANAGED_SERVICES'));
        Assert.isTrue(codes(r).contains('ATLASSIAN_MONTHLY'));
        Assert.isFalse(codes(r).contains('CONSULTING_GENERAL'), 'no consulting product on the quote');

        String terms = storedTerms(q.Id);
        Assert.isTrue(terms.contains('Third-Party License Sales Terms and Conditions'), terms);
        Assert.isTrue(terms.contains('Managed Services General Terms and Conditions'), terms);
        Assert.areEqual(1, occurrences(terms, 'All applicable sales taxes / VAT'), 'shared clause printed once');
    }

    @IsTest
    static void removingAProductRemovesItsTerms() {
        Quote q = newQuote('Global');
        addProducts(q, new List<String>{ 'Jira Cloud Premium', 'Managed Jira Service' });
        Test.startTest();
        delete [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id AND Product2.Name = 'Managed Jira Service'];
        Test.stopTest();

        String terms = storedTerms(q.Id);
        Assert.isFalse(terms.contains('Managed Services General Terms'), terms);
        Assert.isTrue(terms.contains('Third-Party License Sales Terms'), terms);
        Assert.areEqual('Binding', QuoteTermsResolver.resolve(q.Id, null).offerType, 'licences only = binding');
    }

    @IsTest
    static void jodocusLicencesOnlyIsGermanAndBinding() {
        Quote q = newQuote('Jodocus');
        addProducts(q, new List<String>{ 'Jira Cloud Premium' });
        QuoteTermsResolver.Resolution r = QuoteTermsResolver.resolve(q.Id, null);
        Assert.areEqual('Binding', r.offerType);
        Assert.areEqual('German', r.language);
        Assert.isTrue(storedTerms(q.Id).contains('Lizenzbedingungen'));
        Assert.isTrue(QuoteTermsBuilder.introHtml(r).contains('Vielen Dank'));
    }

    @IsTest
    static void gitLabInAnglosphereAddsFlowThroughAndNullVoidOnce() {
        Quote q = newQuote('Anglosphere');
        addProducts(q, new List<String>{ 'GitLab Ultimate' });
        QuoteTermsResolver.Resolution r = QuoteTermsResolver.resolve(q.Id, null);
        Assert.isTrue(codes(r).contains('GITLAB_FLOWTHROUGH'));
        Assert.isTrue(codes(r).contains('DISCOUNT_GITLAB'));
        Assert.areEqual(1, occurrences(storedTerms(q.Id), 'null and void'));
    }

    @IsTest
    static void productSettingOverridesFamily() {
        Quote q = newQuote('Anglosphere');
        addProducts(q, new List<String>{ 'Marketplace App' });
        QuoteTermsResolver.Resolution r = QuoteTermsResolver.resolve(q.Id, null);
        Assert.areEqual('Other_License', r.products[0].groupKey);
        Assert.isTrue(codes(r).contains('DISCOUNT_OTHER'));
        Assert.isFalse(codes(r).contains('ATLASSIAN_MONTHLY'));
    }

    @IsTest
    static void lockedTermsAreNotOverwrittenUntilForced() {
        Quote q = newQuote('Global');
        q.Terms_Locked__c = true;
        q.Terms_And_Conditions__c = '<p>Manually agreed text</p>';
        update q;

        addProducts(q, new List<String>{ 'DevOps Consulting Day' });
        Assert.isTrue(storedTerms(q.Id).contains('Manually agreed text'));

        Test.startTest();
        QuotePdfService.regenerateTerms(q.Id);
        Test.stopTest();
        Assert.isTrue(storedTerms(q.Id).contains('Consulting General Terms and Conditions'));
    }

    @IsTest
    static void killSwitchStopsTriggers() {
        insert new Quote_Terms_Settings__c(SetupOwnerId = UserInfo.getOrganizationId(), Disable_Auto_Terms__c = true);
        Quote q = newQuote('Global');
        addProducts(q, new List<String>{ 'DevOps Consulting Day' });
        Assert.isNull(storedTerms(q.Id));
    }

    @IsTest
    static void switzerlandIsAlwaysBinding() {
        Quote q = newQuote('Switzerland');
        addProducts(q, new List<String>{ 'Jira Cloud Premium', 'DevOps Consulting Day' });
        QuoteTermsResolver.Resolution r = QuoteTermsResolver.resolve(q.Id, null);
        Assert.areEqual('Binding', r.offerType);
        Assert.isTrue(codes(r).contains('CH_ATLASSIAN_SERVICES'));
    }

    @IsTest
    static void controllerAndPdfService() {
        Quote q = newQuote('Global');
        addProducts(q, new List<String>{ 'Jira Cloud Premium', 'Managed Jira Service' });
        Test.setCurrentPage(Page.QuoteModularPdf);
        ApexPages.currentPage().getParameters().put('id', q.Id);
        ApexPages.currentPage().getParameters().put('format', 'html');

        QuotePdfController ctrl = new QuotePdfController();
        Assert.areEqual(2, ctrl.lines.size());
        Assert.isTrue(ctrl.termsHtml.contains('Managed Services General Terms'));
        Assert.isFalse(ctrl.isBinding);

        Test.startTest();
        QuoteTermsResolver.Resolution r = QuotePdfService.getResolution(q.Id, 'English');
        Id docId = QuotePdfService.savePdf(q.Id, null);
        Test.stopTest();
        Assert.areEqual(2, r.products.size());
        Assert.isNotNull(docId);
    }

    @IsTest
    static void flowEntryPoint() {
        Quote q = newQuote('Rest_of_World');
        addProducts(q, new List<String>{ 'Managed Jira Service' });
        update new Quote(Id = q.Id, Terms_Locked__c = true, Terms_And_Conditions__c = '<p>x</p>');
        QuoteTermsService.refreshFromFlow(new List<Id>{ q.Id });
        Assert.isTrue(storedTerms(q.Id).contains('Managed Services'));
    }

    @IsTest
    static void pathValidation() {
        Assert.isTrue(QuotePdfController.isValidPath(Quote.SObjectType, 'Opportunity.Account.Name'));
        Assert.isFalse(QuotePdfController.isValidPath(Quote.SObjectType, 'Opportunity.NoSuchRel__r.Name'));
        Assert.isFalse(QuotePdfController.isValidPath(Quote.SObjectType, ''));
    }

    @IsTest
    static void promoSkipsWhatIsAlreadySoldAndNoticeFollowsProduct() {
        Quote licenceOnly = newQuote('Global');
        addProducts(licenceOnly, new List<String>{ 'Jira Cloud Premium' });
        Set<String> c1 = codes(QuoteTermsResolver.resolve(licenceOnly.Id, null));
        Assert.isTrue(c1.contains('PROMO_MANAGED_ATLASSIAN'), 'upsell managed services');
        Assert.isTrue(c1.contains('TECH_CONTACT'), 'Atlassian technical contact note');

        Quote withManaged = newQuote('Global');
        addProducts(withManaged, new List<String>{ 'Jira Cloud Premium', 'Managed Jira Service' });
        Assert.isFalse(codes(QuoteTermsResolver.resolve(withManaged.Id, null)).contains('PROMO_MANAGED_ATLASSIAN'),
            'no upsell for something already on the quote');
    }

    @IsTest
    static void hideDiscountAndWatermark() {
        Quote q = newQuote('Global');
        addProducts(q, new List<String>{ 'Jira Cloud Premium' });
        update new Quote(Id = q.Id, Hide_Discount__c = true, Watermark_Text__c = 'DRAFT');
        Test.setCurrentPage(Page.QuoteModularPdf);
        ApexPages.currentPage().getParameters().put('id', q.Id);
        QuotePdfController ctrl = new QuotePdfController();
        Assert.isFalse(ctrl.showDiscount);
        Assert.areEqual('DRAFT', ctrl.watermarkText);
        Assert.areEqual(1, ctrl.noticeModules.size());
        Assert.isFalse(ctrl.promoModules.isEmpty());
    }

    @IsTest
    static void serviceReportsErrorsToTheUser() {
        Id notAQuote = [SELECT Id FROM Account LIMIT 1].Id;
        Integer errors = 0;
        Test.startTest();
        try { QuotePdfService.getResolution(notAQuote, null); } catch (AuraHandledException e) { errors++; }
        try { QuotePdfService.regenerateTerms(null); } catch (AuraHandledException e) { errors++; }
        try { QuotePdfService.savePdf(null, null); } catch (AuraHandledException e) { errors++; }
        Test.stopTest();
        Assert.areEqual(3, errors, 'every failure reaches the UI as an AuraHandledException');
    }
}