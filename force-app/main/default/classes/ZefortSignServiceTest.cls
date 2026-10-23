@IsTest
private class ZefortSignServiceTest {
    private static Integer ownerDeniedCreateEsignAttempts = 0;
    private static String ownerDeniedFirstEsignRequestBody;
    private static String ownerDeniedSecondEsignRequestBody;

    @IsTest
    static void testSearchAccountsReturnsMatches() {
        insert new Account(Name = 'Acme Oy');
        insert new Account(Name = 'Globex');

        List<ZefortSignService.AccountSearchOption> rows = ZefortSignService.searchAccounts('Ac');
        System.assertEquals(1, rows.size());
        System.assert(rows[0].label.contains('Acme'));
    }

    @IsTest
    static void testSearchAccountsReturnsEmptyForShortTerm() {
        List<ZefortSignService.AccountSearchOption> rows = ZefortSignService.searchAccounts('A');
        System.assertEquals(0, rows.size());
    }

    @IsTest
    static void testListAccountContactsReturnsContacts() {
        User integrationUser = createIntegrationUser('ctusrdef');
        System.runAs(integrationUser) {
            Account account = new Account(Name = 'With Contacts');
            insert account;

            Contact contact = new Contact(
                AccountId = account.Id,
                LastName = 'Signer',
                Email = 'signer@example.com'
            );
            insert contact;

            List<ZefortSignService.ContactOption> options = ZefortSignService.listAccountContacts(account.Id);
            System.assertEquals(1, options.size());
            System.assertEquals(String.valueOf(contact.Id), options[0].id);
            System.assertEquals('signer@example.com', options[0].email);
        }
    }

    @IsTest
    static void testGetLaunchContextFromAccountRecord() {
        User integrationUser = createIntegrationUser('ctxusr01');
        System.runAs(integrationUser) {
            Account account = new Account(Name = 'Launch Context');
            insert account;

            ZefortSignService.LaunchContext context = ZefortSignService.getLaunchContext(account.Id, 'Account');
            System.assertEquals(true, context.success);
            System.assertEquals(String.valueOf(account.Id), context.accountId);
            System.assertEquals('Account', context.objectApiName);
        }
    }

    @IsTest
    static void testGetLaunchContextIncludesConfiguredInternalSigner() {
        User integrationUser = createIntegrationUser('ctxusr02');
        System.runAs(integrationUser) {
            Account account = new Account(Name = 'Launch Context With Internal Signer');
            insert account;

            Account internalAccount = new Account(Name = 'Internal Team');
            insert internalAccount;

            Contact internalSigner = new Contact(
                AccountId = internalAccount.Id,
                LastName = 'CEO',
                Email = 'ceo@example.com'
            );
            insert internalSigner;

            ZefortSettings__c settings = ZefortSettings__c.getOrgDefaults();
            settings.InternalSignerContactId__c = String.valueOf(internalSigner.Id);
            settings.InternalSignerRole__c = 'approver';
            upsert settings;

            ZefortSignService.LaunchContext context = ZefortSignService.getLaunchContext(account.Id, 'Account');
            System.assertEquals(true, context.success);
            System.assertNotEquals(null, context.internalSignerPrefill);
            System.assertEquals(String.valueOf(internalSigner.Id), context.internalSignerPrefill.contactId);
            System.assertEquals('ceo@example.com', context.internalSignerPrefill.email);
            System.assertEquals('approver', context.internalSignerPrefill.role);
            System.assertEquals('internal_signer', context.internalSignerPrefill.source);
        }
    }

    @IsTest
    static void testStartSignRequestCreatesMappingsAndUsesOwnerFallback() {
        User integrationUser = createIntegrationUser('signusr1');
        System.runAs(integrationUser) {
            ensureAuthKey();

            Account account = new Account(Name = 'Launch');
            insert account;

            Contact signer = new Contact(
                AccountId = account.Id,
                LastName = 'Signer',
                Email = 'signer@example.com'
            );
            insert signer;

            ContentVersion version = new ContentVersion(
                Title = 'NDA',
                PathOnClient = 'NDA.pdf',
                VersionData = Blob.valueOf('pdf-content'),
                FirstPublishLocationId = account.Id
            );
            insert version;

            ZefortSignService.ParticipantSelection participant = new ZefortSignService.ParticipantSelection();
            participant.contactId = String.valueOf(signer.Id);
            participant.role = 'signer';

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
            ZefortSignService.LaunchSubmissionResult result = ZefortSignService.startSignRequest(
                String.valueOf(account.Id),
                'Account',
                String.valueOf(version.Id),
                new List<String>(),
                new List<ZefortSignService.ParticipantSelection>{participant},
                null
            );
            Test.stopTest();

            System.assertEquals(true, result.success);
            System.assertEquals('esign-1', result.zefortEsignId);

            Zefort_Sign_Request__c requestRow = [
                SELECT
                    Id,
                    Request_Title__c,
                    Source_Record_Id__c,
                    Resolved_Account_Id__c,
                    Zefort_Esign_Id__c,
                    Zefort_Contract_Id__c,
                    Zefort_Owner_Id__c,
                    Status__c,
                    Error_Message__c
                FROM Zefort_Sign_Request__c
                WHERE Id = :result.signRequestId
                LIMIT 1
            ];
            System.assertEquals(String.valueOf(account.Id), requestRow.Source_Record_Id__c);
            System.assertEquals(String.valueOf(account.Id), requestRow.Resolved_Account_Id__c);
            System.assertEquals('NDA', requestRow.Request_Title__c);
            System.assertEquals('esign-1', requestRow.Zefort_Esign_Id__c);
            System.assertEquals('contract-1', requestRow.Zefort_Contract_Id__c);
            System.assertEquals(null, requestRow.Zefort_Owner_Id__c);
            System.assertEquals('pending', requestRow.Status__c);
            System.assert(
                requestRow.Error_Message__c != null &&
                requestRow.Error_Message__c.contains('No matching Zefort user found')
            );

            List<Zefort_Sign_Request_Party__c> partyRows = [
                SELECT Email__c, Role__c, Status__c
                FROM Zefort_Sign_Request_Party__c
                WHERE Sign_Request__c = :requestRow.Id
            ];
            System.assertEquals(1, partyRows.size());
            System.assertEquals('jane@example.com', partyRows[0].Email__c);
            System.assertEquals('signer', partyRows[0].Role__c);
            System.assertEquals('pending', partyRows[0].Status__c);
        }
    }

    @IsTest
    static void testStartSignRequestRetriesWithoutOwnerWhenOverrideIsDenied() {
        User integrationUser = createIntegrationUser('signusr9', 'exact-match@example.com');
        System.runAs(integrationUser) {
            ensureAuthKey();

            Account account = new Account(Name = 'Owner Override Retry');
            insert account;

            Contact signer = new Contact(
                AccountId = account.Id,
                LastName = 'Signer',
                Email = 'signer@example.com'
            );
            insert signer;

            ContentVersion version = new ContentVersion(
                Title = 'NDA',
                PathOnClient = 'NDA.pdf',
                VersionData = Blob.valueOf('pdf-content'),
                FirstPublishLocationId = account.Id
            );
            insert version;

            ZefortSignService.ParticipantSelection participant = new ZefortSignService.ParticipantSelection();
            participant.contactId = String.valueOf(signer.Id);
            participant.role = 'signer';

            resetOwnerDeniedCreateEsignMockState();

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new OwnerDeniedCreateEsignCalloutMock());
            ZefortSignService.LaunchSubmissionResult result = ZefortSignService.startSignRequest(
                String.valueOf(account.Id),
                'Account',
                String.valueOf(version.Id),
                new List<String>(),
                new List<ZefortSignService.ParticipantSelection>{participant},
                null
            );
            Test.stopTest();

            System.assertEquals(true, result.success);
            System.assertEquals(2, ownerDeniedCreateEsignAttempts);
            System.assert(ownerDeniedFirstEsignRequestBody.contains('"owner":"user-1"'));
            System.assert(!ownerDeniedSecondEsignRequestBody.contains('"owner":"user-1"'));

            Zefort_Sign_Request__c requestRow = [
                SELECT Zefort_Owner_Id__c, Error_Message__c
                FROM Zefort_Sign_Request__c
                WHERE Id = :result.signRequestId
                LIMIT 1
            ];
            System.assertEquals(null, requestRow.Zefort_Owner_Id__c);
            System.assert(
                requestRow.Error_Message__c != null &&
                requestRow.Error_Message__c.contains('Owner override denied for initiator email exact-match@example.com')
            );
        }
    }

    @IsTest
    static void testStartSignRequestFromClientParsesParticipantJson() {
        User integrationUser = createIntegrationUser('signusr5');
        System.runAs(integrationUser) {
            ensureAuthKey();

            Account account = new Account(Name = 'Launch From Client');
            insert account;

            Contact signer = new Contact(
                AccountId = account.Id,
                LastName = 'Signer',
                Email = 'signer@example.com'
            );
            insert signer;

            ContentVersion version = new ContentVersion(
                Title = 'NDA',
                PathOnClient = 'NDA.pdf',
                VersionData = Blob.valueOf('pdf-content'),
                FirstPublishLocationId = account.Id
            );
            insert version;

            String participantsJson =
                '[{"contactId":"' +
                String.valueOf(signer.Id) +
                '","role":"signer"}]';

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
            ZefortSignService.LaunchSubmissionResult result = ZefortSignService.startSignRequestFromClient(
                String.valueOf(account.Id),
                'Account',
                String.valueOf(version.Id),
                new List<String>(),
                participantsJson,
                null
            );
            Test.stopTest();

            System.assertEquals(true, result.success);
            System.assertEquals('esign-1', result.zefortEsignId);
        }
    }

    @IsTest
    static void testStartSignRequestFromClientAllowsManualAccountFallback() {
        User integrationUser = createIntegrationUser('signusr6');
        System.runAs(integrationUser) {
            ensureAuthKey();

            Account account = new Account(Name = 'Fallback Account');
            insert account;

            Contact signer = new Contact(
                AccountId = account.Id,
                LastName = 'Signer',
                Email = 'signer@example.com'
            );
            insert signer;

            Task sourceTask = new Task(Subject = 'Fallback Source');
            insert sourceTask;

            ContentVersion version = new ContentVersion(
                Title = 'NDA',
                PathOnClient = 'NDA.pdf',
                VersionData = Blob.valueOf('pdf-content'),
                FirstPublishLocationId = sourceTask.Id
            );
            insert version;

            String participantsJson =
                '[{"contactId":"' +
                String.valueOf(signer.Id) +
                '","role":"signer"}]';

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
            ZefortSignService.LaunchSubmissionResult result = ZefortSignService.startSignRequestFromClient(
                String.valueOf(sourceTask.Id),
                'Task',
                String.valueOf(version.Id),
                new List<String>(),
                participantsJson,
                String.valueOf(account.Id)
            );
            Test.stopTest();

            System.assertEquals(true, result.success);
            System.assertEquals('esign-1', result.zefortEsignId);
        }
    }

    @IsTest
    static void testStartSignRequestFromClientRejectsInvalidParticipantPayload() {
        User integrationUser = createIntegrationUser('signusr7');
        System.runAs(integrationUser) {
            Boolean failed = false;
            try {
                ZefortSignService.startSignRequestFromClient(
                    '001000000000001AAA',
                    'Account',
                    '068000000000001AAA',
                    new List<String>(),
                    '{not-valid-json',
                    null
                );
            } catch (AuraHandledException expected) {
                failed = true;
                System.assertNotEquals(null, expected.getMessage());
            }
            System.assertEquals(true, failed);
        }
    }

    @IsTest
    static void testStartSignRequestFromClientRejectsBlankParticipantPayload() {
        User integrationUser = createIntegrationUser('signusr8');
        System.runAs(integrationUser) {
            ensureAuthKey();

            Account account = new Account(Name = 'Blank Participants');
            insert account;

            ContentVersion version = new ContentVersion(
                Title = 'NDA',
                PathOnClient = 'NDA.pdf',
                VersionData = Blob.valueOf('pdf-content'),
                FirstPublishLocationId = account.Id
            );
            insert version;

            Boolean failed = false;
            try {
                ZefortSignService.startSignRequestFromClient(
                    String.valueOf(account.Id),
                    'Account',
                    String.valueOf(version.Id),
                    new List<String>(),
                    '',
                    null
                );
            } catch (AuraHandledException expected) {
                failed = true;
                System.assertNotEquals(null, expected.getMessage());
            }
            System.assertEquals(true, failed);
        }
    }

    @IsTest
    static void testStartSignRequestRejectsManualOrganizationParticipant() {
        User integrationUser = createIntegrationUser('signusr2');
        System.runAs(integrationUser) {
            ensureAuthKey();

            Account account = new Account(Name = 'Launch Manual Participant');
            insert account;

            ContentVersion version = new ContentVersion(
                Title = 'NDA',
                PathOnClient = 'NDA.pdf',
                VersionData = Blob.valueOf('pdf-content'),
                FirstPublishLocationId = account.Id
            );
            insert version;

            ZefortSignService.ParticipantSelection internalSigner =
                new ZefortSignService.ParticipantSelection();
            internalSigner.name = 'Internal CEO';
            internalSigner.email = 'ceo@example.com';
            internalSigner.role = 'signer';

            Boolean failed = false;
            try {
                ZefortSignService.startSignRequest(
                    String.valueOf(account.Id),
                    'Account',
                    String.valueOf(version.Id),
                    new List<String>(),
                    new List<ZefortSignService.ParticipantSelection>{internalSigner},
                    null
                );
            } catch (AuraHandledException expected) {
                failed = true;
            }

            System.assertEquals(true, failed);
        }
    }

    @IsTest
    static void testStartSignRequestAllowsConfiguredInternalSignerOutsideResolvedAccount() {
        User integrationUser = createIntegrationUser('signusr4');
        System.runAs(integrationUser) {
            ensureAuthKey();

            Account account = new Account(Name = 'Launch With Internal Signer');
            insert account;

            Contact accountSigner = new Contact(
                AccountId = account.Id,
                LastName = 'Customer Signer',
                Email = 'customer@example.com'
            );
            insert accountSigner;

            Account internalAccount = new Account(Name = 'Internal Team');
            insert internalAccount;

            Contact internalSigner = new Contact(
                AccountId = internalAccount.Id,
                LastName = 'CEO',
                Email = 'ceo@example.com'
            );
            insert internalSigner;

            ZefortSettings__c settings = ZefortSettings__c.getOrgDefaults();
            settings.InternalSignerContactId__c = String.valueOf(internalSigner.Id);
            upsert settings;

            ContentVersion version = new ContentVersion(
                Title = 'NDA',
                PathOnClient = 'NDA.pdf',
                VersionData = Blob.valueOf('pdf-content'),
                FirstPublishLocationId = account.Id
            );
            insert version;

            ZefortSignService.ParticipantSelection internalParticipant =
                new ZefortSignService.ParticipantSelection();
            internalParticipant.contactId = String.valueOf(internalSigner.Id);
            internalParticipant.role = 'signer';

            ZefortSignService.ParticipantSelection accountParticipant =
                new ZefortSignService.ParticipantSelection();
            accountParticipant.contactId = String.valueOf(accountSigner.Id);
            accountParticipant.role = 'signer';

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
            ZefortSignService.LaunchSubmissionResult result = ZefortSignService.startSignRequest(
                String.valueOf(account.Id),
                'Account',
                String.valueOf(version.Id),
                new List<String>(),
                new List<ZefortSignService.ParticipantSelection>{
                    internalParticipant,
                    accountParticipant
                },
                null
            );
            Test.stopTest();

            System.assertEquals(true, result.success);
            System.assertEquals('esign-1', result.zefortEsignId);
        }
    }

    @IsTest
    static void testStartSignRequestRejectsParticipantWithoutContactId() {
        User integrationUser = createIntegrationUser('signusr3');
        System.runAs(integrationUser) {
            ensureAuthKey();

            Account account = new Account(Name = 'Launch Invalid Manual');
            insert account;

            ContentVersion version = new ContentVersion(
                Title = 'NDA',
                PathOnClient = 'NDA.pdf',
                VersionData = Blob.valueOf('pdf-content'),
                FirstPublishLocationId = account.Id
            );
            insert version;

            ZefortSignService.ParticipantSelection internalSigner =
                new ZefortSignService.ParticipantSelection();
            internalSigner.name = 'Internal CEO';
            internalSigner.email = 'ceo@example.com';
            internalSigner.role = 'signer';

            Boolean failed = false;
            try {
                ZefortSignService.startSignRequest(
                    String.valueOf(account.Id),
                    'Account',
                    String.valueOf(version.Id),
                    new List<String>(),
                    new List<ZefortSignService.ParticipantSelection>{internalSigner},
                    null
                );
            } catch (AuraHandledException expected) {
                failed = true;
            }
            System.assertEquals(true, failed);
        }
    }

    @IsTest
    static void testSyncSignRequestIdsUpdatesRequestAndParties() {
        User integrationUser = createIntegrationUser('syncusr1');
        System.runAs(integrationUser) {
            ensureAuthKey();

            Account account = new Account(Name = 'Sync Import Account');
            insert account;

            Zefort_Sign_Request__c requestRow = new Zefort_Sign_Request__c(
                Source_Record_Id__c = String.valueOf(account.Id),
                Source_Object__c = 'Account',
                Resolved_Account_Id__c = String.valueOf(account.Id),
                Zefort_Esign_Id__c = 'esign-1',
                Zefort_Contract_Id__c = 'contract-1',
                Initiator_User_Id__c = UserInfo.getUserId(),
                Status__c = 'pending',
                Status_Saved_At__c = System.now(),
                Last_Synced_At__c = System.now()
            );
            insert requestRow;

            insert new Zefort_Sign_Request_Party__c(
                Sign_Request__c = requestRow.Id,
                Email__c = 'old@example.com',
                Role__c = 'signer',
                Status__c = 'pending'
            );

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
            Integer syncedCount = ZefortSignService.syncSignRequestIds(new List<Id>{requestRow.Id});
            Test.stopTest();

            System.assertEquals(1, syncedCount);

            Zefort_Sign_Request__c refreshedRequest = [
                SELECT
                    Request_Title__c,
                    Status__c,
                    Error_Message__c,
                    Last_Synced_At__c,
                    Signed_Content_Document_Id__c,
                    Signed_File_Imported_At__c
                FROM Zefort_Sign_Request__c
                WHERE Id = :requestRow.Id
                LIMIT 1
            ];
            System.assertEquals('NDA', refreshedRequest.Request_Title__c);
            System.assertEquals('completed', refreshedRequest.Status__c);
            System.assertEquals(null, refreshedRequest.Error_Message__c);
            System.assertNotEquals(null, refreshedRequest.Last_Synced_At__c);
            System.assertNotEquals(null, refreshedRequest.Signed_Content_Document_Id__c);
            System.assertNotEquals(null, refreshedRequest.Signed_File_Imported_At__c);

            List<Zefort_Sign_Request_Party__c> refreshedParties = [
                SELECT Email__c, Role__c, Status__c
                FROM Zefort_Sign_Request_Party__c
                WHERE Sign_Request__c = :requestRow.Id
            ];
            System.assertEquals(1, refreshedParties.size());
            System.assertEquals('jane@example.com', refreshedParties[0].Email__c);
            System.assertEquals('signer', refreshedParties[0].Role__c);
            System.assertEquals('completed', refreshedParties[0].Status__c);

            List<ContentDocumentLink> importedFiles = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :account.Id
            ];
            System.assertEquals(1, importedFiles.size());
            System.assertEquals(
                refreshedRequest.Signed_Content_Document_Id__c,
                String.valueOf(importedFiles[0].ContentDocumentId)
            );

            ContentVersion importedVersion = [
                SELECT Title, PathOnClient, ContentDocumentId, VersionData
                FROM ContentVersion
                WHERE ContentDocumentId = :importedFiles[0].ContentDocumentId
                LIMIT 1
            ];
            System.assertEquals('NDA signed', importedVersion.Title);
            System.assertEquals('NDA signed.pdf', importedVersion.PathOnClient);
            System.assertEquals('signed-pdf', importedVersion.VersionData.toString());
        }
    }

    @IsTest
    static void testSyncSignRequestIdsAllowsBackgroundSyncForAnotherInitiator() {
        User integrationUser = createIntegrationUser('syncusr2');
        System.runAs(integrationUser) {
            ensureAuthKey();

            User otherUser = createUser('otherusr');
            Account account = new Account(Name = 'Background Sync Import');
            insert account;

            Zefort_Sign_Request__c requestRow = new Zefort_Sign_Request__c(
                Source_Record_Id__c = String.valueOf(account.Id),
                Source_Object__c = 'Account',
                Resolved_Account_Id__c = String.valueOf(account.Id),
                Zefort_Esign_Id__c = 'esign-1',
                Zefort_Contract_Id__c = 'contract-1',
                Initiator_User_Id__c = otherUser.Id,
                Status__c = 'pending',
                Status_Saved_At__c = System.now().addDays(-2),
                Last_Synced_At__c = System.now().addDays(-1)
            );
            insert requestRow;

            insert new Zefort_Sign_Request_Party__c(
                Sign_Request__c = requestRow.Id,
                Email__c = 'old@example.com',
                Role__c = 'signer',
                Status__c = 'pending'
            );

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
            Integer syncedCount = ZefortSignService.syncSignRequestIds(new List<Id>{requestRow.Id});
            Test.stopTest();

            System.assertEquals(1, syncedCount);

            Zefort_Sign_Request__c refreshedRequest = [
                SELECT Status__c, Error_Message__c, Last_Synced_At__c, Signed_Content_Document_Id__c
                FROM Zefort_Sign_Request__c
                WHERE Id = :requestRow.Id
                LIMIT 1
            ];
            System.assertEquals('completed', refreshedRequest.Status__c);
            System.assertNotEquals(null, refreshedRequest.Last_Synced_At__c);
            System.assertEquals(null, refreshedRequest.Error_Message__c);
            System.assertNotEquals(null, refreshedRequest.Signed_Content_Document_Id__c);

            List<Zefort_Sign_Request_Party__c> refreshedParties = [
                SELECT Email__c, Role__c, Status__c
                FROM Zefort_Sign_Request_Party__c
                WHERE Sign_Request__c = :requestRow.Id
            ];
            System.assertEquals(1, refreshedParties.size());
            System.assertEquals('jane@example.com', refreshedParties[0].Email__c);
            System.assertEquals('signer', refreshedParties[0].Role__c);
            System.assertEquals('completed', refreshedParties[0].Status__c);

            System.assertEquals(
                1,
                [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :account.Id]
            );
        }
    }

    @IsTest
    static void testSyncSignRequestIdsDoesNotDuplicateImportedSignedFile() {
        User integrationUser = createIntegrationUser('syncusr4');
        System.runAs(integrationUser) {
            ensureAuthKey();

            Account account = new Account(Name = 'Idempotent Signed Import');
            insert account;

            Zefort_Sign_Request__c requestRow = new Zefort_Sign_Request__c(
                Source_Record_Id__c = String.valueOf(account.Id),
                Source_Object__c = 'Account',
                Resolved_Account_Id__c = String.valueOf(account.Id),
                Zefort_Esign_Id__c = 'esign-1',
                Zefort_Contract_Id__c = 'contract-1',
                Initiator_User_Id__c = UserInfo.getUserId(),
                Status__c = 'pending',
                Status_Saved_At__c = System.now(),
                Last_Synced_At__c = System.now()
            );
            insert requestRow;

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
            Integer firstSyncCount = ZefortSignService.syncSignRequestIds(new List<Id>{requestRow.Id});
            Test.stopTest();

            Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
            Integer secondSyncCount = ZefortSignService.syncSignRequestIds(new List<Id>{requestRow.Id});

            System.assertEquals(1, firstSyncCount);
            System.assertEquals(1, secondSyncCount);
            System.assertEquals(
                1,
                [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :account.Id]
            );
        }
    }

    @IsTest
    static void testSignedFileImportFutureIgnoresMismatchedPayloadLengths() {
        Test.startTest();
        ZefortSignedFileImportQueueable.enqueueImport(
            new List<Id>(),
            new List<String>{ 'esign-1' },
            new List<String>{ 'doc-main' },
            new List<String>{ 'NDA.pdf' },
            new List<String>{ 'NDA' }
        );
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion]);
    }

    @IsTest
    static void testSyncSignRequestIdsPreservesBouncedPartyStatus() {
        User integrationUser = createIntegrationUser('syncusr3');
        System.runAs(integrationUser) {
            ensureAuthKey();

            Zefort_Sign_Request__c requestRow = new Zefort_Sign_Request__c(
                Source_Record_Id__c = '001000000000001AAA',
                Source_Object__c = 'Account',
                Resolved_Account_Id__c = '001000000000001AAA',
                Zefort_Esign_Id__c = 'esign-1',
                Zefort_Contract_Id__c = 'contract-1',
                Initiator_User_Id__c = UserInfo.getUserId(),
                Status__c = 'pending',
                Status_Saved_At__c = System.now(),
                Last_Synced_At__c = System.now()
            );
            insert requestRow;

            insert new Zefort_Sign_Request_Party__c(
                Sign_Request__c = requestRow.Id,
                Email__c = 'old@example.com',
                Role__c = 'signer',
                Status__c = 'pending'
            );

            Test.startTest();
            Test.setMock(HttpCalloutMock.class, new BouncedPartyCalloutMock());
            Integer syncedCount = ZefortSignService.syncSignRequestIds(new List<Id>{requestRow.Id});
            Test.stopTest();

            System.assertEquals(1, syncedCount);

            Zefort_Sign_Request__c refreshedRequest = [
                SELECT Status__c, Error_Message__c, Last_Synced_At__c
                FROM Zefort_Sign_Request__c
                WHERE Id = :requestRow.Id
                LIMIT 1
            ];
            System.assertEquals('bounced', refreshedRequest.Status__c);
            System.assertNotEquals(null, refreshedRequest.Last_Synced_At__c);
            System.assertEquals(null, refreshedRequest.Error_Message__c);

            List<Zefort_Sign_Request_Party__c> refreshedParties = [
                SELECT Email__c, Role__c, Status__c
                FROM Zefort_Sign_Request_Party__c
                WHERE Sign_Request__c = :requestRow.Id
            ];
            System.assertEquals(1, refreshedParties.size());
            System.assertEquals('jane@example.com', refreshedParties[0].Email__c);
            System.assertEquals('signer', refreshedParties[0].Role__c);
            System.assertEquals('bounced', refreshedParties[0].Status__c);
        }
    }

    @IsTest
    static void testRefreshSignRequestsForRecordSkipsRequestsOwnedByAnotherUser() {
        ensureAuthKey();

        Account account = new Account(Name = 'Refresh Access Scope');
        insert account;

        User otherUser = createUser('othrusr2');
        Datetime initialSyncTime = System.now().addDays(-1);
        Datetime initialStatusSavedAt = System.now().addDays(-2);

        Zefort_Sign_Request__c requestRow = new Zefort_Sign_Request__c(
            Source_Record_Id__c = String.valueOf(account.Id),
            Source_Object__c = 'Account',
            Resolved_Account_Id__c = String.valueOf(account.Id),
            Zefort_Esign_Id__c = 'esign-1',
            Zefort_Contract_Id__c = 'contract-1',
            Initiator_User_Id__c = otherUser.Id,
            Status__c = 'pending',
            Status_Saved_At__c = initialStatusSavedAt,
            Last_Synced_At__c = initialSyncTime
        );
        insert requestRow;

        insert new Zefort_Sign_Request_Party__c(
            Sign_Request__c = requestRow.Id,
            Email__c = 'old@example.com',
            Role__c = 'signer',
            Status__c = 'pending'
        );

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
        Integer syncedCount = ZefortSignService.refreshSignRequestsForRecord(String.valueOf(account.Id));
        Test.stopTest();

        System.assertEquals(0, syncedCount);

        Zefort_Sign_Request__c refreshedRequest = [
            SELECT Status__c, Error_Message__c, Last_Synced_At__c, Status_Saved_At__c
            FROM Zefort_Sign_Request__c
            WHERE Id = :requestRow.Id
            LIMIT 1
        ];
        System.assertEquals('pending', refreshedRequest.Status__c);
        System.assertEquals(initialStatusSavedAt, refreshedRequest.Status_Saved_At__c);
        System.assertEquals(initialSyncTime, refreshedRequest.Last_Synced_At__c);
        System.assertEquals(null, refreshedRequest.Error_Message__c);
    }

    @IsTest
    static void testListApisRequireReadableSourceRecord() {
        User integrationUser = createIntegrationUser('listusr1');
        System.runAs(integrationUser) {
            Zefort_Sign_Request__c hiddenRequest = new Zefort_Sign_Request__c(
                Source_Record_Id__c = '001000000000999AAA',
                Source_Object__c = 'Account',
                Zefort_Esign_Id__c = 'esign-hidden',
                Status__c = 'pending'
            );
            insert hiddenRequest;
            insert new Zefort_Sign_Request_Party__c(
                Sign_Request__c = hiddenRequest.Id,
                Email__c = 'hidden@example.com',
                Role__c = 'signer',
                Status__c = 'pending'
            );

            List<ZefortSignService.SignRequestSummary> hiddenSummaries = ZefortSignService.listSignRequests(
                hiddenRequest.Source_Record_Id__c
            );
            System.assertEquals(0, hiddenSummaries.size());

            List<ZefortSignService.SignRequestPartySummary> hiddenParties =
                ZefortSignService.listSignRequestParties(String.valueOf(hiddenRequest.Id));
            System.assertEquals(0, hiddenParties.size());
        }
    }

    @IsTest
    static void testListApisReturnRowsWhenSourceRecordIsReadable() {
        User integrationUser = createIntegrationUser('listusr2');
        System.runAs(integrationUser) {
            Account account = new Account(Name = 'Readable Account');
            insert account;

            Zefort_Sign_Request__c requestRow = new Zefort_Sign_Request__c(
                Source_Record_Id__c = String.valueOf(account.Id),
                Source_Object__c = 'Account',
                Zefort_Esign_Id__c = 'esign-visible',
                Status__c = 'pending'
            );
            insert requestRow;
            insert new Zefort_Sign_Request_Party__c(
                Sign_Request__c = requestRow.Id,
                Email__c = 'visible@example.com',
                Role__c = 'signer',
                Status__c = 'pending'
            );

            List<ZefortSignService.SignRequestSummary> summaries = ZefortSignService.listSignRequests(
                String.valueOf(account.Id)
            );
            System.assertEquals(1, summaries.size());
            System.assertEquals(String.valueOf(requestRow.Id), summaries[0].id);

            List<ZefortSignService.SignRequestPartySummary> parties =
                ZefortSignService.listSignRequestParties(String.valueOf(requestRow.Id));
            System.assertEquals(1, parties.size());
            System.assertEquals('visible@example.com', parties[0].email);
        }
    }

    private static void ensureAuthKey() {
        delete [SELECT Id FROM Zefort_Auth__c];
        insert new Zefort_Auth__c(Name = 'Org Default', API_Key__c = 'test_api_key');
    }

    private static void resetOwnerDeniedCreateEsignMockState() {
        ownerDeniedCreateEsignAttempts = 0;
        ownerDeniedFirstEsignRequestBody = null;
        ownerDeniedSecondEsignRequestBody = null;
    }

    private static User createIntegrationUser(String aliasSeed) {
        User userRow = createUser(aliasSeed, null);
        assignPermissionSet(userRow.Id, 'Zefort_Integration_User');
        return userRow;
    }

    private static User createIntegrationUser(String aliasSeed, String email) {
        User userRow = createUser(aliasSeed, email);
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
        return createUser(aliasSeed, null);
    }

    private static User createUser(String aliasSeed, String email) {
        Profile runningProfile = [
            SELECT Id
            FROM Profile
            WHERE Id = :UserInfo.getProfileId()
            LIMIT 1
        ];

        String normalizedAlias = String.isBlank(aliasSeed) ? 'zuser' : aliasSeed.toLowerCase();
        if (normalizedAlias.length() > 8) {
            normalizedAlias = normalizedAlias.substring(0, 8);
        }
        String uniqueToken = String.valueOf(System.now().getTime());
        String userEmail = String.isBlank(email)
            ? 'zefort-owner-' + uniqueToken + '@example.com'
            : email;

        User userRow = new User(
            FirstName = 'Zefort',
            LastName = 'Owner',
            Alias = normalizedAlias,
            Email = userEmail,
            Username = 'zefort-owner-' + uniqueToken + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Europe/Helsinki',
            ProfileId = runningProfile.Id
        );
        insert userRow;
        return userRow;
    }

    private class OwnerDeniedCreateEsignCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String endpoint = req.getEndpoint() == null ? '' : req.getEndpoint();
            String lowerEndpoint = endpoint.toLowerCase();
            String method = req.getMethod() == null ? 'GET' : req.getMethod().toUpperCase();

            if (lowerEndpoint.contains('/esigns/') && method == 'POST' && !lowerEndpoint.contains('/activate/')) {
                ownerDeniedCreateEsignAttempts += 1;
                if (ownerDeniedCreateEsignAttempts == 1) {
                    ownerDeniedFirstEsignRequestBody = req.getBody();

                    HttpResponse denied = new HttpResponse();
                    denied.setHeader('Content-Type', 'application/json');
                    denied.setStatusCode(403);
                    denied.setBody(
                        '{"detail":"You are not allowed to set another user as an owner of the e-sign."}'
                    );
                    return denied;
                }

                ownerDeniedSecondEsignRequestBody = req.getBody();
            }

            return new ZefortHttpCalloutMock().respond(req);
        }
    }

    private class BouncedPartyCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String endpoint = req.getEndpoint() == null ? '' : req.getEndpoint();
            String lowerEndpoint = endpoint.toLowerCase();
            String method = req.getMethod() == null ? 'GET' : req.getMethod().toUpperCase();

            if (lowerEndpoint.contains('/esigns/') && method == 'GET') {
                HttpResponse response = new HttpResponse();
                response.setHeader('Content-Type', 'application/json');
                response.setStatusCode(200);
                response.setBody(
                    '{"id":"esign-1","title":"NDA","status":"pending","status_saved_at":"2026-01-02T00:00:00Z","parties":[{"id":"party-1","name":"Jane Doe","email":"jane@example.com","role":"signer","status":"bounced","status_saved_at":"2026-01-02T00:00:00Z"}]}'
                );
                return response;
            }

            return new ZefortHttpCalloutMock().respond(req);
        }
    }
}