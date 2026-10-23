public class LicenseJiraScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new LicenseJiraBatch(), LicenseJiraBatch.BATCH_SIZE);
    }

}