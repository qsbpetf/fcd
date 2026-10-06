/**
 * Schedules Atlassian PPC named-credential health probes every 20 minutes.
 *
 * Salesforce does not allow lists in the minutes field, so this registers three
 * hourly jobs at minute 0, 20, and 40.
 *
 * Example:
 * PpcCredentialHealthSchedulable.start();
 * PpcCredentialHealthSchedulable.stop();
 */
public with sharing class PpcCredentialHealthSchedulable implements Schedulable {

    public static final String JOB_NAME_PREFIX = 'PPC Credential Health Check';
    public static final List<String> CRON_EVERY_20_MINUTES = new List<String>{
        '0 0 * * * ?',
        '0 20 * * * ?',
        '0 40 * * * ?'
    };

    public void execute(SchedulableContext context) {
        if (!isEnabled()) {
            System.debug('### PPC health check is disabled, skipping scheduled run');
            return;
        }
        PpcCredentialHealthQueueable.enqueue();
    }

    /**
     * Registers the three hourly jobs that together run every 20 minutes.
     * Aborts any previously scheduled health-check jobs first.
     *
     * @return Ids of the scheduled CronTrigger records
     */
    public static List<String> start() {
        stop();
        List<String> jobIds = new List<String>();
        for (Integer i = 0; i < CRON_EVERY_20_MINUTES.size(); i++) {
            jobIds.add(System.schedule(
                jobName(i),
                CRON_EVERY_20_MINUTES[i],
                new PpcCredentialHealthSchedulable()
            ));
        }
        return jobIds;
    }

    /**
     * Aborts all scheduled PPC credential health-check jobs.
     */
    public static void stop() {
        Set<String> jobNames = new Set<String>();
        for (Integer i = 0; i < CRON_EVERY_20_MINUTES.size(); i++) {
            jobNames.add(jobName(i));
        }
        for (CronTrigger ct : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name IN :jobNames
        ]) {
            System.abortJob(ct.Id);
        }
    }

    @TestVisible
    private static String jobName(Integer index) {
        return JOB_NAME_PREFIX + ' ' + index;
    }

    @TestVisible
    private static Boolean isEnabled() {
        PPC_HealthCheckSettings__c setting = PPC_HealthCheckSettings__c.getOrgDefaults();
        if (setting == null || setting.Id == null) {
            return true;
        }
        return setting.Enabled__c;
    }
}