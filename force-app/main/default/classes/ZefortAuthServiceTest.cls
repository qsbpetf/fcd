@IsTest
private class ZefortAuthServiceTest {
    @TestSetup
    static void setupAuthRow() {
        insert new Zefort_Auth__c(Name = 'Org Default', API_Key__c = 'seed1234');
    }

    @IsTest
    static void testSaveMaskAndReadApiKey() {
        User adminUser = createAdminUser('zauth1');
        System.runAs(adminUser) {
            Test.startTest();
            ZefortAuthService.saveUserApiKey('abcd1234');
            Test.stopTest();

            System.assertEquals(true, ZefortAuthService.hasApiKey());
            System.assertEquals('...1234', ZefortAuthService.getApiKeyMask());
            System.assertEquals('abcd1234', ZefortAuthService.getUserApiKey());
        }
    }

    @IsTest
    static void testGetUserApiKeyThrowsWhenMissing() {
        User adminUser = createAdminUser('zauth2');
        System.runAs(adminUser) {
            delete [SELECT Id FROM Zefort_Auth__c];

            Boolean threw = false;
            try {
                ZefortAuthService.getUserApiKey();
            } catch (AuraHandledException e) {
                threw = true;
            }
            System.assertEquals(true, threw);
        }
    }

    @IsTest
    static void testHasApiKeyFalseWhenAuthRowMissing() {
        User adminUser = createAdminUser('zauth3');
        System.runAs(adminUser) {
            delete [SELECT Id FROM Zefort_Auth__c];
            System.assertEquals(false, ZefortAuthService.hasApiKey());
            System.assertEquals(null, ZefortAuthService.getApiKeyMask());
        }
    }

    @IsTest
    static void testStandardProfileAdminPermsetCanManageApiKey() {
        User integrationAdminUser = createIntegrationAdminUser('zauth4');
        System.runAs(integrationAdminUser) {
            Test.startTest();
            ZefortAuthService.saveUserApiKey('wxyz9876');
            Test.stopTest();

            System.assertEquals(true, Zefort_Auth__c.API_Key__c.getDescribe().isAccessible());
            System.assertEquals(true, Zefort_Auth__c.API_Key__c.getDescribe().isUpdateable());
            System.assertEquals(true, ZefortAuthService.hasApiKey());
            System.assertEquals('...9876', ZefortAuthService.getApiKeyMask());
            System.assertEquals('wxyz9876', ZefortAuthService.getUserApiKey());
        }
    }

    @IsTest
    static void testStandardProfileUserPermsetCanReadApiKey() {
        User integrationUser = createIntegrationUser('zauth5');
        System.runAs(integrationUser) {
            System.assertEquals(true, Zefort_Auth__c.API_Key__c.getDescribe().isAccessible());
            System.assertEquals(false, Zefort_Auth__c.API_Key__c.getDescribe().isUpdateable());
            System.assertEquals(true, ZefortAuthService.hasApiKey());
            System.assertEquals('...1234', ZefortAuthService.getApiKeyMask());
            System.assertEquals('seed1234', ZefortAuthService.getUserApiKey());
        }
    }

    private static User createAdminUser(String aliasSeed) {
        return createAdminUser(aliasSeed, UserInfo.getProfileId());
    }

    private static User createIntegrationAdminUser(String aliasSeed) {
        User userRow = createUser(aliasSeed, findLeastPrivilegeProfileId());
        assignPermissionSet(userRow.Id, 'Zefort_Integration_Admin');
        return userRow;
    }

    private static User createIntegrationUser(String aliasSeed) {
        User userRow = createUser(aliasSeed, findLeastPrivilegeProfileId());
        assignPermissionSet(userRow.Id, 'Zefort_Integration_User');
        return userRow;
    }

    private static User createAdminUser(String aliasSeed, Id profileId) {
        User userRow = createUser(aliasSeed, profileId);
        assignPermissionSet(userRow.Id, 'Zefort_Integration_Admin');
        assignPermissionSet(userRow.Id, 'Zefort_Integration_User');
        return userRow;
    }

    private static Id findLeastPrivilegeProfileId() {
        List<Profile> matches = [
            SELECT Id
            FROM Profile
            WHERE UserType = 'Standard'
            AND PermissionsModifyAllData = false
            ORDER BY Name
            LIMIT 1
        ];
        if (!matches.isEmpty()) {
            return matches[0].Id;
        }
        return UserInfo.getProfileId();
    }

    private static User createUser(String aliasSeed, Id profileId) {
        String normalizedAlias = String.isBlank(aliasSeed) ? 'zauth' : aliasSeed.toLowerCase();
        if (normalizedAlias.length() > 8) {
            normalizedAlias = normalizedAlias.substring(0, 8);
        }
        String uniqueToken = String.valueOf(System.now().getTime()) + aliasSeed;

        User userRow = new User(
            FirstName = 'Zefort',
            LastName = 'Auth',
            Alias = normalizedAlias,
            Email = 'zefort-auth-' + uniqueToken + '@example.com',
            Username = 'zefort-auth-' + uniqueToken + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Europe/Helsinki',
            ProfileId = profileId
        );
        insert userRow;
        return userRow;
    }

    private static void assignPermissionSet(Id assigneeId, String permissionSetName) {
        if (assigneeId == null || String.isBlank(permissionSetName)) {
            return;
        }
        List<PermissionSet> matches = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = :permissionSetName
            LIMIT 1
        ];
        if (matches.isEmpty()) {
            return;
        }
        insert new PermissionSetAssignment(
            AssigneeId = assigneeId,
            PermissionSetId = matches[0].Id
        );
    }
}