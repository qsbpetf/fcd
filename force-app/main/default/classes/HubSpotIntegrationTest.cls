@IsTest
private class HubSpotIntegrationTest {
    @IsTest
    private static void testHierarchyUpdate() {
        Test.setMock(HttpCalloutMock.class, new GeneralHttpCalloutMock());

        Account oldParent = [SELECT Id FROM Account WHERE Name = 'Old Parent' LIMIT 1];
        Account child = [SELECT Id, Name, HS_Object_ID__c, ParentId FROM Account WHERE Name = 'Child' LIMIT 1];

        HubSpotIntegration.FlowRequest fReq = new HubSpotIntegration.FlowRequest();
        fReq.acc = child;
        freq.oldParentId = oldParent.Id;

        Test.startTest();
        HubSpotIntegration.processAccountHierarchyUpdates(new List<HubSpotIntegration.FlowRequest>{ freq });
        Test.stopTest();

        Account parent = [SELECT Id, HS_Object_ID__c FROM Account WHERE Name = 'Parent' LIMIT 1];
        Account updatedChild = [SELECT Id, Name, HS_Object_ID__c, HS_Parent_Company_ID__c, ParentId FROM Account WHERE Name = 'Child' LIMIT 1];

        Assert.areEqual(parent.HS_Object_ID__c, updatedChild.HS_Parent_Company_ID__c, 'Child account has a wrong HubSpot parent company id');
    }

    @IsTest
    private static void testHierarchyUpdateFailWithoutChildId() {
        Test.setMock(HttpCalloutMock.class, new GeneralHttpCalloutMock());

        Account oldParent = [SELECT Id FROM Account WHERE Name = 'Parent Without Id' LIMIT 1];
        Account child = [SELECT Id, Name, HS_Object_ID__c, ParentId FROM Account WHERE Name = 'Child Without Id' LIMIT 1];

        HubSpotIntegration.FlowRequest fReq = new HubSpotIntegration.FlowRequest();
        fReq.acc = child;
        freq.oldParentId = oldParent.Id;

        Test.startTest();
        List<HubSpotIntegration.FlowResponse> flowResponses = HubSpotIntegration.processAccountHierarchyUpdates(new List<HubSpotIntegration.FlowRequest>{ freq });
        Test.stopTest();

        Assert.areEqual('NO_HSID', flowResponses.get(0).status, 'Excepected update to fail without HubSpot id');
    }

    @IsTest
    private static void testHierarchyUpdateWithoutParentId() {
        Test.setMock(HttpCalloutMock.class, new GeneralHttpCalloutMock());

        Account child = [SELECT Id, Name, HS_Object_ID__c, ParentId FROM Account WHERE Name = 'Child Without Parent Id' LIMIT 1];

        HubSpotIntegration.FlowRequest fReq = new HubSpotIntegration.FlowRequest();
        fReq.acc = child;
        freq.oldParentId = null;

        Test.startTest();
        List<HubSpotIntegration.FlowResponse> flowResponses = HubSpotIntegration.processAccountHierarchyUpdates(new List<HubSpotIntegration.FlowRequest>{ freq });
        Test.stopTest();

        Assert.areEqual('OK', flowResponses.get(0).status, 'Excepected update to succeed if there is nothing to update');
    }

    @IsTest
    private static void testHierarchyUpdateWithParentsWithoutId() {
        Test.setMock(HttpCalloutMock.class, new GeneralHttpCalloutMock());

        Account oldParent = [SELECT Id FROM Account WHERE Name = 'Parent Without Id' LIMIT 1];
        Account child = [SELECT Id, Name, HS_Object_ID__c, ParentId FROM Account WHERE Name = 'Child With Parent Without Id' LIMIT 1];

        HubSpotIntegration.FlowRequest fReq = new HubSpotIntegration.FlowRequest();
        fReq.acc = child;
        freq.oldParentId = oldParent.Id;

        Test.startTest();
        List<HubSpotIntegration.FlowResponse> flowResponses = HubSpotIntegration.processAccountHierarchyUpdates(new List<HubSpotIntegration.FlowRequest>{ freq });
        Test.stopTest();

        Assert.areEqual('ERROR', flowResponses.get(0).status, 'Excepected update to fail if parents have no HubSpot ids');
    }

    @IsTest
    private static void testHierarchyDeleteError() {
        Test.setMock(HttpCalloutMock.class, new GeneralHttpCalloutMock(500, 'Error', ''));

        Account oldParent = [SELECT Id FROM Account WHERE Name = 'Old Parent' LIMIT 1];
        Account child = [SELECT Id, Name, HS_Object_ID__c, ParentId FROM Account WHERE Name = 'Child' LIMIT 1];

        HubSpotIntegration.FlowRequest fReq = new HubSpotIntegration.FlowRequest();
        fReq.acc = child;
        freq.oldParentId = oldParent.Id;

        Test.startTest();
        HubSpotIntegration.processAccountHierarchyUpdates(new List<HubSpotIntegration.FlowRequest>{ freq });
        Test.stopTest();

        Account parent = [SELECT Id, HS_Object_ID__c FROM Account WHERE Name = 'Parent' LIMIT 1];
        Account updatedChild = [SELECT Id, Name, HS_Object_ID__c, HS_Parent_Company_ID__c, ParentId FROM Account WHERE Name = 'Child' LIMIT 1];

        Assert.isNull(updatedChild.HS_Parent_Company_ID__c, 'Updating hierarchy to HubSpot should be failed');
    }

    @IsTest
    private static void testHierarchyAddError() {
        Test.setMock(HttpCalloutMock.class, new GeneralHttpCalloutMock(500, 'Error', ''));

        Account oldParent = [SELECT Id FROM Account WHERE Name = 'Old Parent' LIMIT 1];
        Account child = [SELECT Id, Name, HS_Object_ID__c, ParentId FROM Account WHERE Name = 'Child' LIMIT 1];

        HubSpotIntegration.FlowRequest fReq = new HubSpotIntegration.FlowRequest();
        fReq.acc = child;
        freq.oldParentId = null;

        Test.startTest();
        HubSpotIntegration.processAccountHierarchyUpdates(new List<HubSpotIntegration.FlowRequest>{ freq });
        Test.stopTest();

        Account parent = [SELECT Id, HS_Object_ID__c FROM Account WHERE Name = 'Parent' LIMIT 1];
        Account updatedChild = [SELECT Id, Name, HS_Object_ID__c, HS_Parent_Company_ID__c, ParentId FROM Account WHERE Name = 'Child' LIMIT 1];

        Assert.isNull(updatedChild.HS_Parent_Company_ID__c, 'Updating hierarchy to HubSpot should be failed');
    }

    @IsTest
    private static void testAccountUpdateFail() {
        Account child = [SELECT Id, Name, HS_Object_ID__c, ParentId FROM Account WHERE Name = 'Child' LIMIT 1];

        Test.startTest();
        child.Name = child.Name.rightPad(300, 'X');
        HubSpotIntegration hsi = new HubSpotIntegration(null);
        hsi.updateAccounts(new List<Account>{ child });
        Test.stopTest();

        Account updatedChild = [SELECT Id, Name, HS_Object_ID__c, ParentId FROM Account WHERE Name = 'Child' LIMIT 1];

        Assert.isNotNull(updatedChild, 'Account should be found with old name as the account name update should have failed');
    }

    @IsTest
    private static void testQueueable() {
        Test.setMock(HttpCalloutMock.class, new GeneralHttpCalloutMock());

        Account oldParent = [SELECT Id FROM Account WHERE Name = 'Old Parent' LIMIT 1];
        Account child = [SELECT Id, Name, HS_Object_ID__c, ParentId FROM Account WHERE Name = 'Child' LIMIT 1];

        HubSpotIntegration.FlowRequest fReq = new HubSpotIntegration.FlowRequest();
        fReq.acc = child;
        freq.oldParentId = oldParent.Id;

        Test.startTest();
        HubSpotIntegrationQueueable.processAccountHierarchyUpdateWithQueueable(new List<HubSpotIntegration.FlowRequest>{ fReq });
        Test.stopTest();

        Account parent = [SELECT Id, HS_Object_ID__c FROM Account WHERE Name = 'Parent' LIMIT 1];
        Account updatedChild = [SELECT Id, Name, HS_Object_ID__c, HS_Parent_Company_ID__c, ParentId FROM Account WHERE Name = 'Child' LIMIT 1];

        Assert.areEqual(parent.HS_Object_ID__c, updatedChild.HS_Parent_Company_ID__c, 'Child account has a wrong HubSpot parent company id');
    }

    @IsTest
    private static void testQueueableWithMultipleRequests() {
        Test.setMock(HttpCalloutMock.class, new GeneralHttpCalloutMock());

        Account oldParent = [SELECT Id FROM Account WHERE Name = 'Old Parent' LIMIT 1];
        Account child = [SELECT Id, Name, HS_Object_ID__c, ParentId FROM Account WHERE Name = 'Child' LIMIT 1];

        HubSpotIntegration.FlowRequest fReq = new HubSpotIntegration.FlowRequest();
        fReq.acc = child;
        freq.oldParentId = oldParent.Id;

        HubSpotIntegration.FlowRequest fReq2 = new HubSpotIntegration.FlowRequest();
        fReq2.acc = child;
        freq2.oldParentId = null;

        Test.startTest();
        HubSpotIntegrationQueueable.processAccountHierarchyUpdateWithQueueable(new List<HubSpotIntegration.FlowRequest>{ fReq, fReq2 });
        Test.stopTest();

        Account parent = [SELECT Id, HS_Object_ID__c FROM Account WHERE Name = 'Parent' LIMIT 1];
        Account updatedChild = [SELECT Id, Name, HS_Object_ID__c, HS_Parent_Company_ID__c, ParentId FROM Account WHERE Name = 'Child' LIMIT 1];

        Assert.areEqual(parent.HS_Object_ID__c, updatedChild.HS_Parent_Company_ID__c, 'Child account has a wrong HubSpot parent company id');
    }

    @TestSetup
    private static void makeData() {
        Account parent = new Account(Name = 'Parent', HS_Object_ID__c = 111);
        insert parent;

        Account oldParent = new Account(Name = 'Old Parent', HS_Object_ID__c = 222);
        insert oldParent;

        Account child = new Account(Name = 'Child', ParentId = parent.Id, HS_Object_ID__c = 999);
        insert child;

        Account parentWithoutId = new Account(Name = 'Parent Without Id');
        insert parentWithoutId;

        Account childWithoutId = new Account(Name = 'Child Without Id', ParentId = parentWithoutId.Id);
        insert childWithoutId;

        Account childWithoutParentId = new Account(Name = 'Child Without Parent Id', HS_Object_ID__c = 123);
        insert childWithoutParentId;

        Account childWithParentWithoutId = new Account(Name = 'Child With Parent Without Id', ParentId = parentWithoutId.Id, HS_Object_ID__c = 456);
        insert childWithParentWithoutId;
    }
}