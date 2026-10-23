@IsTest
private class ZefortParticipantPrefillServiceTest {
    @IsTest
    static void testGetPrefilledParticipantsReturnsContextRuleParticipants() {
        User integrationUser = createIntegrationUser('prefil1');
        System.runAs(integrationUser) {
            Account account = new Account(Name = 'Prefill Account');
            insert account;

            Contact contextContact = new Contact(
                AccountId = account.Id,
                LastName = 'Context Contact',
                Email = 'context@example.com'
            );
            insert contextContact;

            Case caseRow = new Case(
                AccountId = account.Id,
                ContactId = contextContact.Id,
                Subject = 'Prefill Case',
                Origin = 'Phone',
                Status = 'New'
            );
            insert caseRow;

            List<ZefortParticipantPrefillService.PrefillParticipant> participants =
                ZefortParticipantPrefillService.getPrefilledParticipants(
                    String.valueOf(caseRow.Id),
                    'Case'
                );

            System.assertEquals(1, participants.size());
            ZefortParticipantPrefillService.PrefillParticipant contextParticipant = participants[0];
            System.assertEquals('context_rule', contextParticipant.source);
            System.assertEquals('signer', contextParticipant.role);
            System.assertEquals('Context Contact', contextParticipant.name);
            System.assertEquals('context@example.com', contextParticipant.email);
        }
    }

    @IsTest
    static void testGetPrefilledParticipantsReturnsEmptyForInvalidContext() {
        System.assertEquals(
            0,
            ZefortParticipantPrefillService.getPrefilledParticipants(null, 'Case').size()
        );
        System.assertEquals(
            0,
            ZefortParticipantPrefillService.getPrefilledParticipants('not-an-id', 'Case').size()
        );
        System.assertEquals(
            0,
            ZefortParticipantPrefillService.getPrefilledParticipants('001000000000999AAA', 'Account').size()
        );
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

        String normalizedAlias = String.isBlank(aliasSeed) ? 'zprefill' : aliasSeed.toLowerCase();
        if (normalizedAlias.length() > 8) {
            normalizedAlias = normalizedAlias.substring(0, 8);
        }
        String uniqueToken = String.valueOf(System.now().getTime()) + aliasSeed;

        User userRow = new User(
            FirstName = 'Zefort',
            LastName = 'Prefill',
            Alias = normalizedAlias,
            Email = 'zefort-prefill-' + uniqueToken + '@example.com',
            Username = 'zefort-prefill-' + uniqueToken + '@example.com',
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