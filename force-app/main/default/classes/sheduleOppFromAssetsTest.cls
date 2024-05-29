/* 
* @author Alan Abishev - Ceterna LTD
* @createddate 21/04/2017
* @edited 07/05/2017
*/

@isTest
public class sheduleOppFromAssetsTest {
    @isTest
    public static void testMain(){
        
        test.startTest();
        String jobId = System.schedule('batchOppFromAssets',
                                       scheduleOppFromAssets.sched,
                                       new scheduleOppFromAssets());
        
        
        // Get the information from the CronTrigger API object
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, 
                          NextFireTime
                          FROM CronTrigger WHERE id = :jobId];
        
        // Verify the expressions are the same
        System.assertEquals(scheduleOppFromAssets.sched, 
                            ct.CronExpression);
        
        // Verify the job has not run
        System.assertEquals(0, ct.TimesTriggered);
        
        
        //DateTime tmrw = system.today().addDays(1);
        // Verify the next time the job will run
        //System.assertEquals(string.valueOf(tmrw), 
         //                   String.valueOf(ct.NextFireTime));
        
        
        Test.stopTest();
             
    }
}