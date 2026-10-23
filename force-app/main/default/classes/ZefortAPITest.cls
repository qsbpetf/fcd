@IsTest
private class ZefortAPITest {
    private class NullBodyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(200);
            response.setBody('null');
            return response;
        }
    }

    private class PartyNotFoundMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(200);
            response.setBody('{"results":[]}');
            return response;
        }
    }

    @TestSetup
    static void makeData(){
        // Create test settings
        ZefortSettings__c settings = new ZefortSettings__c();
        
        // Safely set Region__c if the field exists
        try {
            settings.put('Region__c', 'sandbox');
        } catch (Exception e) {
            System.debug('Region__c field not available yet: ' + e.getMessage());
        }
        
        // Set MiddlewareUrl__c field if it's required
        try {
            settings.put('MiddlewareUrl__c', 'https://example.com');
        } catch (Exception e) {
            System.debug('MiddlewareUrl__c field error: ' + e.getMessage());
        }
        
        insert settings;

        Zefort_Auth__c auth = new Zefort_Auth__c();
        auth.Name = 'Org Default';
        auth.API_Key__c = 'test_api_key';
        insert auth;
    }
    
    @IsTest
    static void testGetContractsForParty() {
        // Given
        String accountId = 'test123';
        
        // When
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
        Object result = ZefortAPI.getContractsForParty(accountId);
        Test.stopTest();
        
        // Then
        Map<String, Object> resultMap = (Map<String, Object>)result;
        List<Object> contracts = (List<Object>)resultMap.get('results');
        System.assertEquals(1, contracts.size(), 'Should return one contract');
        
        Map<String, Object> contract = (Map<String, Object>)contracts[0];
        System.assertEquals('123', contract.get('id'), 'Should return correct contract ID');
        
        Map<String, Object> attributes = (Map<String, Object>)contract.get('attributes');
        System.assertEquals('Test Contract', attributes.get('title'), 'Should return correct contract title');
    }
    
    @IsTest
    static void testCreateParty() {
        // Given
        // Create a test account first
        Account testAccount = new Account(
            Name = 'Test Account',
            BillingCountry = 'United States'
        );
        insert testAccount;
        
        // When
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
        Object result = ZefortAPI.createParty(testAccount.Id);
        Test.stopTest();
        
        // Then
        Map<String, Object> resultMap = (Map<String, Object>)result;
        System.assertEquals('party123', resultMap.get('id'), 'Should return party ID');
        System.assertEquals('test123', resultMap.get('external_id'), 'Should return external ID');
    }

    @IsTest
    static void testFindZefortUserByEmailReturnsExactMatch() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
        Map<String, Object> user = ZefortAPI.findZefortUserByEmail('exact-match@example.com');
        Test.stopTest();

        System.assertEquals('user-1', user.get('id'));
        System.assertEquals('exact-match@example.com', user.get('email'));
    }

    @IsTest
    static void testFindZefortUserByEmailDoesNotFallbackToFirstResult() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
        Map<String, Object> user = ZefortAPI.findZefortUserByEmail('close-match@example.com');
        Test.stopTest();

        System.assertEquals(0, user.size());
    }

    @IsTest
    static void testCheckPartyExists() {
        Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
        Test.startTest();
        Map<String, Object> existsResult = (Map<String, Object>) ZefortAPI.checkParty('test123');
        Test.stopTest();

        System.assertEquals(true, existsResult.get('exists'));
        System.assertNotEquals(null, existsResult.get('party'));
    }

    @IsTest
    static void testCheckPartyMissing() {
        Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
        Test.startTest();
        Map<String, Object> missingResult = (Map<String, Object>) ZefortAPI.checkParty('missing');
        Test.stopTest();
        System.assertEquals(false, missingResult.get('exists'));
    }

    @IsTest
    static void testCheckPartyNullResponse() {
        Test.setMock(HttpCalloutMock.class, new NullBodyMock());
        Test.startTest();
        Map<String, Object> nullResult = (Map<String, Object>) ZefortAPI.checkParty('anything');
        Test.stopTest();
        System.assertEquals(false, nullResult.get('exists'));
        System.assertEquals('No response from Zefort API', nullResult.get('message'));
    }

    @IsTest
    static void testCreateContractUploadCreateEsignActivateAndGetEsign() {
        List<Account> accounts = [SELECT Id FROM Account LIMIT 1];
        if (accounts.isEmpty()) {
            insert new Account(Name = 'Contract Flow Account');
        }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ZefortHttpCalloutMock());
        Map<String, Object> contract = ZefortAPI.createContract('Pilot Contract');
        Map<String, Object> upload = ZefortAPI.uploadContractFile(
            String.valueOf(contract.get('id')),
            'contract.pdf',
            'application/pdf',
            Blob.valueOf('pdf')
        );
        List<Map<String, Object>> parties = new List<Map<String, Object>>{
            new Map<String, Object>{
                'name' => 'Signer',
                'email' => 'signer@example.com',
                'role' => 'signer',
                'authentication_type' => 'email'
            }
        };
        Map<String, Object> esign = ZefortAPI.createEsign(
            String.valueOf(contract.get('id')),
            'doc-main',
            new List<String>{'doc-attachment'},
            parties,
            'owner-1',
            'Pilot Contract'
        );
        Map<String, Object> activated = ZefortAPI.activateEsign(String.valueOf(esign.get('id')));
        Map<String, Object> fetched = ZefortAPI.getEsign(String.valueOf(esign.get('id')));
        Blob signedPdf = ZefortAPI.downloadSignedEsignDocument(
            String.valueOf(esign.get('id')),
            'doc-main'
        );
        Test.stopTest();

        System.assertEquals('contract-1', contract.get('id'));
        System.assertEquals(1, ((List<Object>) upload.get('documents')).size());
        System.assertEquals('esign-1', esign.get('id'));
        System.assertEquals('pending', activated.get('status'));
        System.assertEquals('completed', fetched.get('status'));
        System.assertEquals('signed-pdf', signedPdf.toString());
    }

    @IsTest
    static void testCreateEsignAndUploadValidation() {
        Boolean missingContractThrown = false;
        try {
            ZefortAPI.createEsign(
                null,
                'doc-main',
                new List<String>(),
                new List<Map<String, Object>>{ new Map<String, Object>{'email' => 'a@example.com'} },
                null,
                null
            );
        } catch (AuraHandledException e) {
            missingContractThrown = true;
        }
        System.assertEquals(true, missingContractThrown);

        Boolean missingMainDocumentThrown = false;
        try {
            ZefortAPI.createEsign(
                'contract-1',
                null,
                new List<String>(),
                new List<Map<String, Object>>{ new Map<String, Object>{'email' => 'a@example.com'} },
                null,
                null
            );
        } catch (AuraHandledException e) {
            missingMainDocumentThrown = true;
        }
        System.assertEquals(true, missingMainDocumentThrown);

        Boolean missingParticipantsThrown = false;
        try {
            ZefortAPI.createEsign('contract-1', 'doc-main', new List<String>(), new List<Map<String, Object>>(), null, null);
        } catch (AuraHandledException e) {
            missingParticipantsThrown = true;
        }
        System.assertEquals(true, missingParticipantsThrown);

        Boolean missingFileBlobThrown = false;
        try {
            ZefortAPI.uploadContractFile('contract-1', 'file.pdf', 'application/pdf', null);
        } catch (AuraHandledException e) {
            missingFileBlobThrown = true;
        }
        System.assertEquals(true, missingFileBlobThrown);
    }

    @IsTest
    static void testGetContractsForPartyReturnsPartyNotFoundMessage() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new PartyNotFoundMock());
        Map<String, Object> result = (Map<String, Object>) ZefortAPI.getContractsForParty('001000000000001AAA');
        Test.stopTest();

        System.assertEquals(0, ((List<Object>) result.get('results')).size());
        System.assertEquals('Party not found in Zefort', result.get('message'));
    }

    @IsTest
    static void testFindZefortUserByEmailBlankInputReturnsEmpty() {
        Map<String, Object> result = ZefortAPI.findZefortUserByEmail('   ');
        System.assertEquals(0, result.size());
    }

    @IsTest
    static void testActivateAndGetEsignValidateRequiredId() {
        Boolean activateThrown = false;
        try {
            ZefortAPI.activateEsign(null);
        } catch (AuraHandledException e) {
            activateThrown = true;
        }
        System.assertEquals(true, activateThrown);

        Boolean getThrown = false;
        try {
            ZefortAPI.getEsign(' ');
        } catch (AuraHandledException e) {
            getThrown = true;
        }
        System.assertEquals(true, getThrown);

        Boolean downloadMissingDocumentThrown = false;
        try {
            ZefortAPI.downloadSignedEsignDocument('esign-1', null);
        } catch (AuraHandledException e) {
            downloadMissingDocumentThrown = true;
        }
        System.assertEquals(true, downloadMissingDocumentThrown);
    }
}