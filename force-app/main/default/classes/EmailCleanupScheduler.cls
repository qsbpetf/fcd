/**
 * Scheduler that starts the archive + delete chain.
 * Schedule it via Execute Anonymous:
 *   System.schedule('EmailMessage Cleanup - Weekly', '0 0 2 ? * SUN', new EmailCleanupScheduler());
 */
public without sharing class EmailCleanupScheduler implements Schedulable {

    public static final Integer RETENTION_YEARS = 3;

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new EmailArchiveBatch(RETENTION_YEARS), 200);
    }
}