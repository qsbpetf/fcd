/* 
* @author Alan Abishev - Ceterna LTD
* @createddate 21/04/2017
* @edited 28/04/2017
*/

global class scheduleOppFromAssets implements Schedulable {
    
    
    public static String sched = '0 00 00 * * ?';  //Every Day at Midnight 
    
    /*global static String scheduleMe() {
        scheduleOppFromAssets SC = new scheduleOppFromAssets(); 
        return System.schedule('My batch Job', sched, SC);
    }*/
    
    global void execute(SchedulableContext sc) {
        
        batchOppFromAssets btch = new batchOppFromAssets();
        ID batchprocessid = Database.executeBatch(btch,50);           
    }
}