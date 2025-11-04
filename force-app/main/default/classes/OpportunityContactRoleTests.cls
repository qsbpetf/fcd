@isTest
global class OpportunityContactRoleTests {
    static testMethod void testUpdateContactsJiraSyncFlag() {        
        AutomationSettings__c automationSettings = new AutomationSettings__c();
        automationSettings.setupownerid = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].get(0).id;
        automationSettings.Automation_Enabled__c = false;
        automationSettings.Validation_Rule_Enabled__c = false;
        insert automationSettings;

        Account a = New Account(Name = 'test account', Payment_terms__c = '10 Days');
        insert a;
        Contact c = New Contact(LastName = 'last name');
        insert c;
        Opportunity o = New Opportunity(Name = 'opportunity', Account = a, StageName = 'Explore', CloseDate = system.today(), Payment_Terms__c = '10 Days');
        insert o;
        OpportunityContactRole ocr = New OpportunityContactRole(ContactId = c.Id, OpportunityId = o.Id);
        insert ocr;
        Contact c2 = New Contact(LastName = 'last name2');
        insert c2;
        o.StageName = 'Closed won - awaiting approval';
        update o;
        OpportunityContactRole ocr2 = New OpportunityContactRole(ContactId = c2.Id, OpportunityId = o.Id);
        insert ocr2;
    }
}