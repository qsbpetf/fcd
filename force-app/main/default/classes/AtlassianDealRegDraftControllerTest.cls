/**
 * Unit tests for AtlassianDealRegDraftController.
 */
@IsTest
private class AtlassianDealRegDraftControllerTest {

    private static final String DRAFT_CREATION = '{"id":"D-12345","status":"DRAFT"}';
    private static final String JOB_STATUS = '{"jobId":"job-123","status":"IN_PROGRESS","registrationId":"D-12345"}';
    private static final String REG_RESPONSE = '{"id":"D-12345","dealName":"Test","customerDomain":"example.com","status":"DRAFT"}';

    @TestSetup
    static void setup() {
        AtlassianRegSubmission__c sub = new AtlassianRegSubmission__c(
            Name = 'Test',
            Registration_Id__c = 'D-12345',
            Partner_Account_Id__c = '0012000000yYBawAAG',
            Status__c = 'DRAFT'
        );
        insert sub;
    }

    @IsTest
    static void testCreateDealDraft() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addResponse('registrations/v1/deals', 201, DRAFT_CREATION);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Map<String, Object> result = AtlassianDealRegDraftController.createDealDraft(
            '0012000000yYBawAAG',
            '{"dealName":"Test","customerDomain":"example.com","programType":"DEAL_REGISTRATION"}'
        );
        Test.stopTest();

        System.assertNotEquals(null, result.get('recordId'), 'Should return recordId');
        System.assertEquals('D-12345', result.get('registrationId'), 'Wrong registrationId');
        System.assertEquals('DRAFT', result.get('status'), 'Wrong status');

        AtlassianRegSubmission__c sub = [SELECT Id, Registration_Id__c, Status__c FROM AtlassianRegSubmission__c WHERE Registration_Id__c = 'D-12345' LIMIT 1];
        System.assertEquals('DRAFT', sub.Status__c, 'Status should be DRAFT');
    }

    @IsTest
    static void testUpdateDealDraft() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addResponse('registrations/v1/deals', 204, '');
        Test.setMock(HttpCalloutMock.class, mock);

        Id recordId = [SELECT Id FROM AtlassianRegSubmission__c LIMIT 1].Id;

        Test.startTest();
        AtlassianDealRegDraftController.updateDealDraft(recordId, '{"dealName":"Updated"}');
        Test.stopTest();

        System.assertEquals(1, mock.getRequests().size(), 'Should have 1 request');
    }

    @IsTest
    static void testSubmitDealDraft() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addResponse('registrations/v1/deals', 202, JOB_STATUS);
        Test.setMock(HttpCalloutMock.class, mock);

        Id recordId = [SELECT Id FROM AtlassianRegSubmission__c LIMIT 1].Id;

        Test.startTest();
        Map<String, Object> result = AtlassianDealRegDraftController.submitDealDraft(recordId);
        Test.stopTest();

        System.assertEquals('job-123', result.get('jobId'), 'Wrong jobId');
        System.assertEquals('IN_PROGRESS', result.get('status'), 'Wrong status');

        AtlassianRegSubmission__c sub = [SELECT Job_Id__c, Status__c FROM AtlassianRegSubmission__c WHERE Id = :recordId];
        System.assertEquals('job-123', sub.Job_Id__c, 'Job Id should be set');
        System.assertEquals('IN_PROGRESS', sub.Status__c, 'Status should be IN_PROGRESS');
    }

    @IsTest
    static void testPollJobStatus() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addOkResponse('jobs/v1', '{"jobId":"job-123","status":"COMPLETED","registrationId":"D-12345"}');
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianRegSubmission__c sub = [SELECT Id FROM AtlassianRegSubmission__c LIMIT 1];
        sub.Job_Id__c = 'job-123';
        sub.Status__c = 'IN_PROGRESS';
        update sub;

        Test.startTest();
        Map<String, Object> result = AtlassianDealRegDraftController.pollJobStatus(sub.Id);
        Test.stopTest();

        System.assertEquals('COMPLETED', result.get('status'), 'Wrong status');
    }

    @IsTest
    static void testGetSubmissionRecord() {
        Id recordId = [SELECT Id FROM AtlassianRegSubmission__c LIMIT 1].Id;

        Map<String, Object> result = AtlassianDealRegDraftController.getSubmissionRecord(recordId);

        System.assertEquals('D-12345', result.get('Registration_Id__c'), 'Wrong registration id');
        System.assertEquals('0012000000yYBawAAG', result.get('Partner_Account_Id__c'), 'Wrong partner account');
    }

    @IsTest
    static void testUpdateDealDraftByRegistrationId() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addResponse('registrations/v1/deals', 204, '');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        AtlassianDealRegDraftController.updateDealDraftByRegistrationId(
            '0012000000yYBawAAG',
            'D-12345',
            '{"dealName":"Updated"}'
        );
        Test.stopTest();

        System.assertEquals(1, mock.getRequests().size(), 'Should have 1 request');
    }

    @IsTest
    static void testFindSubmissionByRegistrationId_found() {
        Map<String, Object> result = AtlassianDealRegDraftController.findSubmissionByRegistrationId(
            '0012000000yYBawAAG',
            'D-12345'
        );

        System.assertNotEquals(null, result.get('recordId'), 'Should find record');
        System.assertEquals('DRAFT', result.get('status'), 'Wrong status');
    }

    @IsTest
    static void testFindSubmissionByRegistrationId_notFound() {
        Map<String, Object> result = AtlassianDealRegDraftController.findSubmissionByRegistrationId(
            '0012000000yYBawAAG',
            'D-NONEXISTENT'
        );

        System.assertEquals(true, result.isEmpty(), 'Should return empty when not found');
    }

    @IsTest
    static void testCreateLocalDealDraft() {
        Test.startTest();
        Map<String, Object> result = AtlassianDealRegDraftController.createLocalDealDraft(
            '0012000000yYBawAAG',
            '{"dealName":"Local Deal","programType":"DEAL_REGISTRATION","customerDomain":"example.com"}'
        );
        Test.stopTest();

        Id newRecordId = (Id) result.get('recordId');
        System.assertNotEquals(null, newRecordId, 'Should return recordId');
        System.assertEquals(null, result.get('registrationId'), 'No API id yet');

        AtlassianRegSubmission__c sub = [
            SELECT Registration_Id__c, Draft_Payload_JSON__c, Deal_Name__c, Program_Type__c
            FROM AtlassianRegSubmission__c
            WHERE Id = :newRecordId
        ];
        System.assertEquals(null, sub.Registration_Id__c, 'Registration Id should be null');
        System.assertEquals('Local Deal', sub.Deal_Name__c, 'Deal name from JSON');
        System.assertEquals('DEAL_REGISTRATION', sub.Program_Type__c, 'Program type');
    }

    @IsTest
    static void testSaveDraftPayload_localOnly() {
        AtlassianRegSubmission__c sub = new AtlassianRegSubmission__c(
            Name = 'Local',
            Partner_Account_Id__c = '0012000000yYBawAAG',
            Program_Type__c = 'DEAL_REGISTRATION',
            Draft_Payload_JSON__c = '{"dealName":"Old","programType":"DEAL_REGISTRATION"}'
        );
        insert sub;

        Test.startTest();
        AtlassianDealRegDraftController.saveDraftPayload(
            sub.Id,
            '{"dealName":"New Name","programType":"DEAL_REGISTRATION","customerDomain":"x.com"}'
        );
        Test.stopTest();

        sub = [
            SELECT Draft_Payload_JSON__c, Deal_Name__c
            FROM AtlassianRegSubmission__c
            WHERE Id = :sub.Id
        ];
        System.assert(sub.Draft_Payload_JSON__c.contains('New Name'), 'Payload updated');
        System.assertEquals('New Name', sub.Deal_Name__c, 'Deal name updated');
    }

    @IsTest
    static void testSaveDraftPayload_withRemoteDraft() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addResponse('registrations/v1/deals', 204, '');
        Test.setMock(HttpCalloutMock.class, mock);

        Id recordId = [SELECT Id FROM AtlassianRegSubmission__c LIMIT 1].Id;

        Test.startTest();
        AtlassianDealRegDraftController.saveDraftPayload(
            recordId,
            '{"dealName":"Patched","programType":"DEAL_REGISTRATION"}'
        );
        Test.stopTest();

        System.assertEquals(1, mock.getRequests().size(), 'Should PATCH Atlassian');
    }

    @IsTest
    static void testSyncDraftToAtlassian() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addResponse('registrations/v1/deals', 201, DRAFT_CREATION);
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianRegSubmission__c sub = new AtlassianRegSubmission__c(
            Name = 'Pending',
            Partner_Account_Id__c = '0012000000yYBawAAG',
            Program_Type__c = 'DEAL_REGISTRATION',
            Draft_Payload_JSON__c = '{"dealName":"Sync Me","programType":"DEAL_REGISTRATION"}'
        );
        insert sub;

        Test.startTest();
        Map<String, Object> result = AtlassianDealRegDraftController.syncDraftToAtlassian(sub.Id);
        Test.stopTest();

        System.assertEquals('D-12345', result.get('registrationId'), 'API id');

        sub = [SELECT Registration_Id__c, Status__c, Name FROM AtlassianRegSubmission__c WHERE Id = :sub.Id];
        System.assertEquals('D-12345', sub.Registration_Id__c, 'Stored registration id');
        System.assertEquals('DRAFT', sub.Status__c, 'Status from API');
        System.assertEquals('Draft D-12345', sub.Name, 'Name updated');
    }

    @IsTest
    static void testSyncDraftToAtlassian_alreadySynced() {
        Id recordId = [SELECT Id FROM AtlassianRegSubmission__c LIMIT 1].Id;
        Boolean gotError = false;
        try {
            AtlassianDealRegDraftController.syncDraftToAtlassian(recordId);
        } catch (Exception e) {
            gotError = true;
        }
        System.assertEquals(true, gotError, 'syncDraftToAtlassian should fail when registration exists');
    }

    @IsTest
    static void testSubmitDealDraft_requiresRegistrationId() {
        AtlassianRegSubmission__c sub = new AtlassianRegSubmission__c(
            Name = 'Local only',
            Partner_Account_Id__c = '0012000000yYBawAAG',
            Program_Type__c = 'DEAL_REGISTRATION',
            Draft_Payload_JSON__c = '{"dealName":"X","programType":"DEAL_REGISTRATION"}'
        );
        insert sub;

        Boolean gotError = false;
        try {
            AtlassianDealRegDraftController.submitDealDraft(sub.Id);
        } catch (Exception e) {
            gotError = true;
        }
        System.assertEquals(true, gotError, 'submitDealDraft should fail without registration id');
    }
}