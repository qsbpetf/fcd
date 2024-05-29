@isTest public class AttachmentTriggerTest {
    @isTest static void caseAfterInsertTest() {
        Case randomCase = new Case(Subject = 'AttachmentTriggerTest');
        insert randomCase;
        Attachment randomAttachment = new Attachment(ParentId = randomCase.Id, Name = 'test.txt', Body = Blob.valueOf('Test'));
        JSFS.JiraTriggerTestHelper.testAfterInsert(randomAttachment);
    }
}