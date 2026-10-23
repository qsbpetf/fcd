@IsTest
private class ZefortSettingsTest {
    @IsTest
    static void testSetAndGetInternalSigner() {
        Account account = new Account(Name = 'Internal Signer Account');
        insert account;

        Contact contact = new Contact(
            AccountId = account.Id,
            LastName = 'Signer',
            Email = 'internal-signer@example.com'
        );
        insert contact;

        Test.startTest();
        ZefortSettings.setInternalSigner(String.valueOf(contact.Id), 'approver');
        ZefortSettings.ContactOption configured = ZefortSettings.getInternalSigner();
        Test.stopTest();

        System.assertNotEquals(null, configured);
        System.assertEquals(String.valueOf(contact.Id), configured.id);
        System.assertEquals('internal-signer@example.com', configured.email);
        System.assertEquals('approver', configured.role);
    }

    @IsTest
    static void testSearchContactsMatchesNameAndEmail() {
        Account account = new Account(Name = 'Search Account');
        insert account;

        insert new List<Contact>{
            new Contact(
                AccountId = account.Id,
                LastName = 'Alpha',
                Email = 'alpha@example.com'
            ),
            new Contact(
                AccountId = account.Id,
                LastName = 'NoEmail'
            )
        };

        List<ZefortSettings.ContactOption> matches = ZefortSettings.searchContacts('alp');
        System.assertEquals(1, matches.size());
        System.assert(matches[0].label.contains('alpha@example.com'));
    }

    @IsTest
    static void testSetInternalSignerDefaultsRoleToSigner() {
        Account account = new Account(Name = 'Internal Signer Default Role');
        insert account;

        Contact contact = new Contact(
            AccountId = account.Id,
            LastName = 'Default Role',
            Email = 'default-role@example.com'
        );
        insert contact;

        Test.startTest();
        ZefortSettings.setInternalSigner(String.valueOf(contact.Id), null);
        ZefortSettings.ContactOption configured = ZefortSettings.getInternalSigner();
        Test.stopTest();

        System.assertNotEquals(null, configured);
        System.assertEquals('signer', configured.role);
    }
}