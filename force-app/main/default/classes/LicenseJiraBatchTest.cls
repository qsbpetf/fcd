@IsTest
private class LicenseJiraBatchTest {
    @TestSetup
    static void setup() {
        insert new AutomationSettings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Automation_Enabled__c = true,
            Validation_Rule_Enabled__c = false
        );
    }

    @IsTest
    static void stampsRequestedOnForLicenseInWindow() {
        Opportunity opp = insertClosedLicenseOpp(Date.today().addDays(30), 'License', 'Closed won - awaiting approval');

        Test.startTest();
        Database.executeBatch(new LicenseJiraBatch(), LicenseJiraBatch.BATCH_SIZE);
        Test.stopTest();

        opp = [SELECT Jira_Issue_Requested_On__c, Jira_Issue_Key__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, opp.Jira_Issue_Requested_On__c);
        System.assertEquals(null, opp.Jira_Issue_Key__c);
    }

    @IsTest
    static void ignoresOtherOpportunities() {
        Opportunity selected = insertClosedLicenseOpp(Date.today().addDays(10), 'License', 'Closed won - awaiting approval');

        // Test.startTest() resets governor limits. Closing two Opportunities in one transaction
        // exceeds the SOQL limit because of the existing Opportunity automation (KAM Plan flow).
        Test.startTest();
        Opportunity other = insertClosedLicenseOpp(Date.today().addDays(10), 'License', 'Closed won - awaiting approval');

        Database.executeBatch(new LicenseJiraBatch(), LicenseJiraBatch.BATCH_SIZE);
        Test.stopTest();

        Map<Id, Opportunity> result = new Map<Id, Opportunity>([
            SELECT Jira_Issue_Requested_On__c
            FROM Opportunity
            WHERE Id IN :new Set<Id>{ selected.Id, other.Id }
        ]);
        System.assertNotEquals(null, result.get(selected.Id).Jira_Issue_Requested_On__c);
        System.assertEquals(null, result.get(other.Id).Jira_Issue_Requested_On__c);
    }

    @IsTest
    static void skipsEndDateBeforeNotBefore() {
        assertNotStamped(LicenseJiraBatch.NOT_BEFORE.addDays(-1), 'License', 'Closed won - awaiting approval');
    }

    @IsTest
    static void skipsEndDateAfterWindow() {
        assertNotStamped(Date.today().addDays(LicenseJiraBatch.WINDOW_DAYS + 1), 'License', 'Closed won - awaiting approval');
    }

    @IsTest
    static void skipsNonLicenseUnit() {
        assertNotStamped(Date.today().addDays(10), 'Hour', 'Closed won - awaiting approval');
    }

    @IsTest
    static void skipsOpenStage() {
        assertNotStamped(Date.today().addDays(10), 'License', 'Explore');
    }

    @IsTest
    static void skipsWhenKeyAlreadySet() {
        Opportunity withKey = insertClosedLicenseOpp(Date.today().addDays(10), 'License', 'Closed won - awaiting approval');
        withKey.Jira_Issue_Key__c = 'PRJ-1';
        update withKey;

        Test.startTest();
        runFor(withKey.Id);
        Test.stopTest();

        withKey = [SELECT Jira_Issue_Requested_On__c FROM Opportunity WHERE Id = :withKey.Id];
        System.assertEquals(null, withKey.Jira_Issue_Requested_On__c);
    }

    @IsTest
    static void skipsWhenRequestAlreadySet() {
        Opportunity alreadyRequested = insertClosedLicenseOpp(Date.today().addDays(10), 'License', 'Closed won - awaiting approval');
        Datetime original = System.now().addDays(-2);
        alreadyRequested.Jira_Issue_Requested_On__c = original;
        update alreadyRequested;

        Test.startTest();
        runFor(alreadyRequested.Id);
        Test.stopTest();

        alreadyRequested = [SELECT Jira_Issue_Requested_On__c FROM Opportunity WHERE Id = :alreadyRequested.Id];
        System.assertEquals(original, alreadyRequested.Jira_Issue_Requested_On__c);
    }

    @IsTest
    static void stampsSourceNotRenewal() {
        Opportunity renewal = insertOpenOpp('Renewal');
        Opportunity source = insertClosedLicenseOpp(Date.today().addDays(15), 'License', 'Closed won - awaiting approval');
        source.Renewal_Opportunity__c = renewal.Id;
        update source;

        Test.startTest();
        Database.executeBatch(new LicenseJiraBatch(), LicenseJiraBatch.BATCH_SIZE);
        Test.stopTest();

        source = [SELECT Jira_Issue_Requested_On__c FROM Opportunity WHERE Id = :source.Id];
        renewal = [SELECT Jira_Issue_Requested_On__c FROM Opportunity WHERE Id = :renewal.Id];
        System.assertNotEquals(null, source.Jira_Issue_Requested_On__c);
        System.assertEquals(null, renewal.Jira_Issue_Requested_On__c);
    }

    @IsTest
    static void schedulerStartsBatch() {
        Opportunity opp = insertClosedLicenseOpp(Date.today().addDays(10), 'License', 'Closed won - awaiting approval');

        Test.startTest();
        new LicenseJiraScheduler().execute(null);
        Test.stopTest();

        opp = [SELECT Jira_Issue_Requested_On__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, opp.Jira_Issue_Requested_On__c);
    }

    @IsTest
    static void selectsOnlyFirstRequestWithBlankKey() {
        Id oppId = '006000000000002';
        Opportunity oldOpp = new Opportunity(Id = oppId, Jira_Issue_Key__c = null);
        Opportunity requested = new Opportunity(Id = oppId, Jira_Issue_Requested_On__c = System.now(), Jira_Issue_Key__c = null);
        Opportunity alreadyDated = new Opportunity(
            Id = oppId,
            Jira_Issue_Requested_On__c = System.now().addDays(-1)
        );
        Opportunity withKey = new Opportunity(
            Id = oppId,
            Jira_Issue_Requested_On__c = System.now(),
            Jira_Issue_Key__c = 'PRJ-9'
        );

        System.assertEquals(1, OpportunityTriggerHandler.selectJiraIssueRequests(
            new List<Opportunity>{ requested },
            new Map<Id, Opportunity>{ oppId => oldOpp }
        ).size());
        System.assertEquals(0, OpportunityTriggerHandler.selectJiraIssueRequests(
            new List<Opportunity>{ requested },
            new Map<Id, Opportunity>{ oppId => alreadyDated }
        ).size());
        System.assertEquals(0, OpportunityTriggerHandler.selectJiraIssueRequests(
            new List<Opportunity>{ withKey },
            new Map<Id, Opportunity>{ oppId => oldOpp }
        ).size());
        System.assertEquals(
            OpportunityTriggerHandler.JIRA_PROJECT_ID,
            'PRJ01'
        );
        System.assertEquals(OpportunityTriggerHandler.JIRA_ISSUE_TYPE_ID, 'ISS05');
    }

    private static void runFor(Id opportunityId) {
        Database.executeBatch(new LicenseJiraBatch(), LicenseJiraBatch.BATCH_SIZE);
    }

    private static void assertNotStamped(Date endDate, String unitOfMeasure, String stageName) {
        Opportunity opp = insertClosedLicenseOpp(endDate, unitOfMeasure, stageName);
        Test.startTest();
        runFor(opp.Id);
        Test.stopTest();
        opp = [SELECT Jira_Issue_Requested_On__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, opp.Jira_Issue_Requested_On__c);
    }

    private static Opportunity insertClosedLicenseOpp(Date endDate, String unitOfMeasure, String stageName) {
        Account account = new Account(Name = 'License Jira ' + String.valueOf(Math.random()), Payment_terms__c = '10 Days');
        insert account;
        Opportunity opp = new Opportunity(
            Name = 'License Jira',
            AccountId = account.Id,
            StageName = 'Explore',
            CloseDate = Date.today(),
            Payment_Terms__c = '10 Days',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert opp;

        Product2 product = new Product2(
            Name = 'License product',
            IsActive = true,
            Unit_of_Measure__c = unitOfMeasure
        );
        insert product;
        PricebookEntry entry = new PricebookEntry(
            Product2Id = product.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            UnitPrice = 1,
            IsActive = true
        );
        insert entry;
        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = entry.Id,
            Quantity = 1,
            UnitPrice = 1,
            Renewal__c = 'New',
            License_Start_date__c = endDate.addDays(-30),
            License_end_date__c = endDate
        );
        if (stageName != 'Explore') {
            opp.StageName = stageName;
            opp.Customer_PO_Number__c = 'PO-1';
            update opp;
        }
        return opp;
    }

    private static Opportunity insertOpenOpp(String name) {
        Account account = new Account(Name = name + ' account', Payment_terms__c = '10 Days');
        insert account;
        Opportunity opp = new Opportunity(
            Name = name,
            AccountId = account.Id,
            StageName = 'Explore',
            CloseDate = Date.today(),
            Payment_Terms__c = '10 Days'
        );
        insert opp;
        return opp;
    }
}