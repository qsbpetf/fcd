@IsTest
private class ZefortRecordResolverTest {
    @IsTest
    static void testResolveRecordContextForSupportedObjects() {
        Account account = new Account(Name = 'Resolver Account');
        insert account;

        Contact contact = new Contact(
            AccountId = account.Id,
            LastName = 'Resolver Contact',
            Email = 'resolver@example.com'
        );
        insert contact;

        Opportunity opportunity = new Opportunity(
            Name = 'Resolver Opportunity',
            AccountId = account.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert opportunity;

        Case caseRow = new Case(
            AccountId = account.Id,
            ContactId = contact.Id,
            Subject = 'Resolver Case',
            Origin = 'Web',
            Status = 'New'
        );
        insert caseRow;

        ZefortRecordResolver.ResolutionResult accountResult = ZefortRecordResolver.resolveRecordContext(
            String.valueOf(account.Id),
            null
        );
        System.assertEquals(true, accountResult.success);
        System.assertEquals('Account', accountResult.objectApiName);
        System.assertEquals(String.valueOf(account.Id), accountResult.accountId);

        ZefortRecordResolver.ResolutionResult opportunityResult = ZefortRecordResolver.resolveRecordContext(
            String.valueOf(opportunity.Id),
            'Opportunity'
        );
        System.assertEquals(true, opportunityResult.success);
        System.assertEquals(String.valueOf(account.Id), opportunityResult.accountId);
        System.assertEquals('Opportunity', opportunityResult.objectApiName);

        ZefortRecordResolver.ResolutionResult contactResult = ZefortRecordResolver.resolveRecordContext(
            String.valueOf(contact.Id),
            'Contact'
        );
        System.assertEquals(true, contactResult.success);
        System.assertEquals(String.valueOf(account.Id), contactResult.accountId);
        System.assertEquals(String.valueOf(contact.Id), contactResult.contextContactId);

        ZefortRecordResolver.ResolutionResult caseResult = ZefortRecordResolver.resolveRecordContext(
            String.valueOf(caseRow.Id),
            'Case'
        );
        System.assertEquals(true, caseResult.success);
        System.assertEquals(String.valueOf(account.Id), caseResult.accountId);
        System.assertEquals(String.valueOf(contact.Id), caseResult.contextContactId);
    }

    @IsTest
    static void testResolveRecordContextErrorScenarios() {
        ZefortRecordResolver.ResolutionResult blankIdResult = ZefortRecordResolver.resolveRecordContext(
            null,
            'Account'
        );
        System.assertEquals(false, blankIdResult.success);
        System.assertEquals('Record ID is required.', blankIdResult.message);

        ZefortRecordResolver.ResolutionResult cannotInferObjectResult = ZefortRecordResolver.resolveRecordContext(
            'not-an-id',
            null
        );
        System.assertEquals(false, cannotInferObjectResult.success);
        System.assertEquals('Unable to determine source object.', cannotInferObjectResult.message);

        ZefortRecordResolver.ResolutionResult noConfigResult = ZefortRecordResolver.resolveRecordContext(
            '00T000000000001AAA',
            'Task'
        );
        System.assertEquals(false, noConfigResult.success);
        System.assertEquals('No active account resolver configuration found.', noConfigResult.message);

        ZefortRecordResolver.ResolutionResult notFoundResult = ZefortRecordResolver.resolveRecordContext(
            '500000000000000AAA',
            'Case'
        );
        System.assertEquals(false, notFoundResult.success);
        System.assert(notFoundResult.message.contains('Failed to resolve source record context'));
    }

    @IsTest
    static void testResolvePathValuesReturnsSafeValues() {
        Account account = new Account(Name = 'Path Account');
        insert account;

        Opportunity opportunity = new Opportunity(
            Name = 'Path Opportunity',
            AccountId = account.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(7)
        );
        insert opportunity;

        Map<String, String> values = ZefortRecordResolver.resolvePathValues(
            String.valueOf(opportunity.Id),
            'Opportunity',
            new List<String>{
                'AccountId',
                'Account.Name',
                'Name FROM User',
                null
            }
        );
        System.assertEquals(String.valueOf(account.Id), values.get('AccountId'));
        System.assertEquals('Path Account', values.get('Account.Name'));
        System.assertEquals(null, values.get('Name FROM User'));
    }

    @IsTest
    static void testResolvePathValuesHandlesInvalidInputs() {
        Map<String, String> withNoParams = ZefortRecordResolver.resolvePathValues(null, 'Account', null);
        System.assertEquals(0, withNoParams.size());

        Map<String, String> withInvalidRecord = ZefortRecordResolver.resolvePathValues(
            '001000000000999AAA',
            'Account',
            new List<String>{'Id'}
        );
        System.assertEquals(0, withInvalidRecord.size());

        Map<String, String> withOnlyUnsafePaths = ZefortRecordResolver.resolvePathValues(
            '001000000000999AAA',
            'Account',
            new List<String>{'Id,Name'}
        );
        System.assertEquals(0, withOnlyUnsafePaths.size());
    }
}