@isTest public class CaseUpdatedTriggerTest {
    @isTest static void testTriggerAfterUpdate() {
        // JSFS.JiraTriggerTestHelper.testAfterUpdate('Case');
        Case c = New Case(Subject = 'test');
        insert c;
        update c;
    }
}