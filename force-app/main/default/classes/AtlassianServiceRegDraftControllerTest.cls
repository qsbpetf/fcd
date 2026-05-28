/**
 * Unit tests for AtlassianServiceRegDraftController.
 */
@IsTest
private class AtlassianServiceRegDraftControllerTest {

    private static final String DRAFT_CREATION = '{"id":"CD-67890","status":"DRAFT"}';
    private static final String JOB_STATUS = '{"jobId":"job-456","status":"IN_PROGRESS","registrationId":"CD-67890"}';

    @TestSetup
    static void setup() {
        AtlassianRegSubmission__c sub = new AtlassianRegSubmission__c(
            Name = 'Test Service',
            Registration_Id__c = 'CD-67890',
            Partner_Account_Id__c = '0012000000yYBawAAG',
            Program_Type__c = 'SERVICE_REGISTRATION',
            Status__c = 'DRAFT'
        );
        insert sub;
    }

    @IsTest
    static void testCreateServiceDraft() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addResponse('registrations/v1/services', 201, DRAFT_CREATION);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Map<String, Object> result = AtlassianServiceRegDraftController.createServiceDraft(
            '0012000000yYBawAAG',
            '{"dealName":"Test Service","customerDomain":"example.com","programType":"SERVICE_REGISTRATION"}'
        );
        Test.stopTest();

        System.assertNotEquals(null, result.get('recordId'), 'Should return recordId');
        System.assertEquals('CD-67890', result.get('registrationId'), 'Wrong registrationId');
        System.assertEquals('DRAFT', result.get('status'), 'Wrong status');

        AtlassianRegSubmission__c sub = [SELECT Id, Registration_Id__c, Status__c, Program_Type__c FROM AtlassianRegSubmission__c WHERE Registration_Id__c = 'CD-67890' LIMIT 1];
        System.assertEquals('DRAFT', sub.Status__c, 'Status should be DRAFT');
        System.assertEquals('SERVICE_REGISTRATION', sub.Program_Type__c, 'Program type should be SERVICE_REGISTRATION');
    }

    @IsTest
    static void testUpdateServiceDraft() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addResponse('registrations/v1/services', 204, '');
        Test.setMock(HttpCalloutMock.class, mock);

        Id recordId = [SELECT Id FROM AtlassianRegSubmission__c LIMIT 1].Id;

        Test.startTest();
        AtlassianServiceRegDraftController.updateServiceDraft(recordId, '{"dealName":"Updated Service"}');
        Test.stopTest();

        System.assertEquals(1, mock.getRequests().size(), 'Should have 1 request');
    }

    @IsTest
    static void testSubmitServiceDraft() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addResponse('registrations/v1/services', 202, JOB_STATUS);
        Test.setMock(HttpCalloutMock.class, mock);

        Id recordId = [SELECT Id FROM AtlassianRegSubmission__c LIMIT 1].Id;

        Test.startTest();
        Map<String, Object> result = AtlassianServiceRegDraftController.submitServiceDraft(recordId);
        Test.stopTest();

        System.assertEquals('job-456', result.get('jobId'), 'Wrong jobId');
        System.assertEquals('IN_PROGRESS', result.get('status'), 'Wrong status');

        AtlassianRegSubmission__c sub = [SELECT Job_Id__c, Status__c FROM AtlassianRegSubmission__c WHERE Id = :recordId];
        System.assertEquals('job-456', sub.Job_Id__c, 'Job Id should be set');
        System.assertEquals('IN_PROGRESS', sub.Status__c, 'Status should be IN_PROGRESS');
    }

    @IsTest
    static void testUpdateServiceDraftByRegistrationId() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addResponse('registrations/v1/services', 204, '');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        AtlassianServiceRegDraftController.updateServiceDraftByRegistrationId(
            '0012000000yYBawAAG',
            'CD-67890',
            '{"dealName":"Updated"}'
        );
        Test.stopTest();

        System.assertEquals(1, mock.getRequests().size(), 'Should have 1 request');
    }

    @IsTest
    static void testCreateLocalServiceDraft() {
        Test.startTest();
        Map<String, Object> result = AtlassianServiceRegDraftController.createLocalServiceDraft(
            '0012000000yYBawAAG',
            '{"dealName":"Local Svc","programType":"SERVICE_REGISTRATION","customerDomain":"example.com"}'
        );
        Test.stopTest();

        Id newRecordId = (Id) result.get('recordId');
        System.assertNotEquals(null, newRecordId, 'Should return recordId');
        AtlassianRegSubmission__c sub = [
            SELECT Registration_Id__c, Program_Type__c, Deal_Name__c
            FROM AtlassianRegSubmission__c
            WHERE Id = :newRecordId
        ];
        System.assertEquals(null, sub.Registration_Id__c, 'No remote id yet');
        System.assertEquals('SERVICE_REGISTRATION', sub.Program_Type__c, 'Program');
        System.assertEquals('Local Svc', sub.Deal_Name__c, 'Deal name');
    }

    @IsTest
    static void testSyncServiceDraftToAtlassian() {
        GeneralHttpCalloutMock mock = new GeneralHttpCalloutMock();
        mock.addResponse('registrations/v1/services', 201, DRAFT_CREATION);
        Test.setMock(HttpCalloutMock.class, mock);

        AtlassianRegSubmission__c sub = new AtlassianRegSubmission__c(
            Name = 'Pending Svc',
            Partner_Account_Id__c = '0012000000yYBawAAG',
            Program_Type__c = 'SERVICE_REGISTRATION',
            Draft_Payload_JSON__c = '{"dealName":"Svc Sync","programType":"SERVICE_REGISTRATION"}'
        );
        insert sub;

        Test.startTest();
        Map<String, Object> result = AtlassianDealRegDraftController.syncDraftToAtlassian(sub.Id);
        Test.stopTest();

        System.assertEquals('CD-67890', result.get('registrationId'), 'Service registration id');

        sub = [SELECT Registration_Id__c FROM AtlassianRegSubmission__c WHERE Id = :sub.Id];
        System.assertEquals('CD-67890', sub.Registration_Id__c, 'Stored');
    }

    @IsTest
    static void testSubmitServiceDraft_requiresRegistrationId() {
        AtlassianRegSubmission__c sub = new AtlassianRegSubmission__c(
            Name = 'Local svc',
            Partner_Account_Id__c = '0012000000yYBawAAG',
            Program_Type__c = 'SERVICE_REGISTRATION',
            Draft_Payload_JSON__c = '{"dealName":"Y","programType":"SERVICE_REGISTRATION"}'
        );
        insert sub;

        Boolean gotError = false;
        try {
            AtlassianServiceRegDraftController.submitServiceDraft(sub.Id);
        } catch (Exception e) {
            gotError = true;
        }
        System.assertEquals(true, gotError, 'submitServiceDraft should fail without registration id');
    }
}