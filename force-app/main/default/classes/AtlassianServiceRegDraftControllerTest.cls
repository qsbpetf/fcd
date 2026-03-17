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
}
