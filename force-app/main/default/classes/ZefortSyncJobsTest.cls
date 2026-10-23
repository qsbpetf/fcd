@IsTest
private class ZefortSyncJobsTest {
    @IsTest
    static void testQueueableExecuteWithNoIds() {
        Test.startTest();
        System.enqueueJob(new ZefortSyncQueueable(null));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Zefort_Sign_Request__c]);
    }

    @IsTest
    static void testQueueableExecuteSyncsProvidedIds() {
        User integrationUser = createIntegrationUser('syncque1');
        System.runAs(integrationUser) {
            ensureAuthKey();
            Account account = new Account(Name = 'Queueable Account');
            insert account;

            Zefort_Sign_Request__c requestRow = new Zefort_Sign_Request__c(
                Source_Record_Id__c = String.valueOf(account.Id),
                Source_Object__c = 'Account',
                Resolved_Account_Id__c = String.valueOf(account.Id),
                Zefort_Esign_Id__c = 'esign-1',
                Zefort_Contract_Id__c = 'contract-1',
                Status__c = 'pending',
                Status_Saved_At__c = System.now().addDays(-1),
                Last_Synced_At__c = System.now().addDays(-1),
                Initiator_User_Id__c = UserInfo.getUserId()
            );
            insert requestRow;

            insert new Zefort_Sign_Request_Party__c(
                Sign_Request__c = requestRow.Id,
                Email__c = 'old@example.com',
                Role__c = 'signer',
                Status__c = 'pending'
            );

            Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
            Test.startTest();
            System.enqueueJob(new ZefortSyncQueueable(new List<Id>{requestRow.Id}));
            Test.stopTest();

            Zefort_Sign_Request__c refreshed = [
                SELECT Status__c, Error_Message__c, Last_Synced_At__c
                FROM Zefort_Sign_Request__c
                WHERE Id = :requestRow.Id
                LIMIT 1
            ];
            System.assertEquals('completed', refreshed.Status__c);
            System.assertEquals(null, refreshed.Error_Message__c);
            System.assertNotEquals(null, refreshed.Last_Synced_At__c);
        }
    }

    @IsTest
    static void testSchedulerSkipsWhenNoCandidates() {
        User integrationUser = createIntegrationUser('syncemp1');
        System.runAs(integrationUser) {
            Test.startTest();
            String jobId = System.schedule(
                'Zefort Sync Empty ' + String.valueOf(System.now().getTime()),
                '0 0 0 1 1 ? 2099',
                new ZefortSyncScheduler()
            );
            Test.stopTest();

            System.assertNotEquals(null, jobId);
            System.assertEquals(0, [SELECT COUNT() FROM Zefort_Sign_Request__c]);
        }
    }

    @IsTest
    static void testSchedulerChunksAndSyncsCandidates() {
        User integrationUser = createIntegrationUser('syncsch1');
        System.runAs(integrationUser) {
            ensureAuthKey();
            Account account = new Account(Name = 'Scheduler Account');
            insert account;

            List<Zefort_Sign_Request__c> requestRows = new List<Zefort_Sign_Request__c>();
            for (Integer i = 0; i < 25; i++) {
                requestRows.add(
                    new Zefort_Sign_Request__c(
                        Source_Record_Id__c = String.valueOf(account.Id),
                        Source_Object__c = 'Account',
                        Resolved_Account_Id__c = String.valueOf(account.Id),
                        Zefort_Esign_Id__c = 'esign-1',
                        Zefort_Contract_Id__c = 'contract-1',
                        Status__c = 'pending',
                        Status_Saved_At__c = System.now().addDays(-2),
                        Last_Synced_At__c = System.now().addDays(-1),
                        Initiator_User_Id__c = UserInfo.getUserId()
                    )
                );
            }
            insert requestRows;

            Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
            Test.startTest();
            System.schedule(
                'Zefort Sync Batch ' + String.valueOf(System.now().getTime()),
                '0 0 0 1 1 ? 2099',
                new ZefortSyncScheduler()
            );
            Test.stopTest();

            Integer queuedSyncJobs = [
                SELECT COUNT()
                FROM AsyncApexJob
                WHERE JobType = 'Queueable'
                    AND ApexClass.Name = 'ZefortSyncQueueable'
            ];
            System.assertEquals(2, queuedSyncJobs);
        }
    }

    private static void ensureAuthKey() {
        delete [SELECT Id FROM Zefort_Auth__c];
        insert new Zefort_Auth__c(Name = 'Org Default', API_Key__c = 'test_api_key');
    }

    private static User createIntegrationUser(String aliasSeed) {
        User userRow = createUser(aliasSeed);
        assignPermissionSet(userRow.Id, 'Zefort_Integration_Admin');
        assignPermissionSet(userRow.Id, 'Zefort_Integration_User');
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

    private static User createUser(String aliasSeed) {
        Profile runningProfile = [
            SELECT Id
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            LIMIT 1
        ];

        String normalizedAlias = String.isBlank(aliasSeed) ? 'zsync' : aliasSeed.toLowerCase();
        if (normalizedAlias.length() > 8) {
            normalizedAlias = normalizedAlias.substring(0, 8);
        }
        String uniqueToken = String.valueOf(System.now().getTime()) + aliasSeed;

        User userRow = new User(
            FirstName = 'Zefort',
            LastName = 'Sync',
            Alias = normalizedAlias,
            Email = 'zefort-sync-' + uniqueToken + '@example.com',
            Username = 'zefort-sync-' + uniqueToken + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Europe/Helsinki',
            ProfileId = runningProfile.Id
        );
        insert userRow;
        return userRow;
    }
}