/**
 * Scheduled batch job to recalculate T2/T3 amounts for opportunities modified in the last 24 hours.
 *
 * Schedule examples:
 * - Daily at midnight: TierCalcScheduledJob.schedule('Daily Tier Calc', '0 0 0 * * ?');
 * - Every hour: TierCalcScheduledJob.schedule('Hourly Tier Calc', '0 0 * * * ?');
 *
 * Manual execution:
 * Database.executeBatch(new TierCalcScheduledJob(), 200);
 */
public class TierCalcScheduledJob implements Database.Batchable<SObject>, Database.Stateful, Schedulable {

    // Stateful counters
    @TestVisible private Integer totalProcessed = 0;
    @TestVisible private Integer totalErrors = 0;
    @TestVisible private List<String> errorMessages = new List<String>();

    // Configurable lookback period (in hours)
    private Integer lookbackHours = 24;
    private Set<Id> targetOppIds;

    // Default constructor - processes opportunities from last 24 hours
    public TierCalcScheduledJob() {
        this(24);
    }

    // Constructor with custom lookback period - number of hours to look back for modified opportunities
    public TierCalcScheduledJob(Integer lookbackHours) {
        this.lookbackHours = lookbackHours;
    }

    // Constructor with specific Opportunity IDs
    public TierCalcScheduledJob(Set<Id> oppIds) {
        this.targetOppIds = oppIds;
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, 200);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (targetOppIds != null && !targetOppIds.isEmpty()) {
            System.debug('Starting batch for specific IDs: ' + targetOppIds);
            return Database.getQueryLocator([
                SELECT Id, Name, LastModifiedDate
                FROM Opportunity
                WHERE Id IN :targetOppIds
            ]);
        }

        Datetime cutoffTime = Datetime.now().addHours(-lookbackHours);

        // Get record count for debugging
        Integer recordCount = [SELECT COUNT() FROM Opportunity WHERE LastModifiedDate >= :cutoffTime];
        System.debug('Number of records found in batch: ' + recordCount);

        return Database.getQueryLocator([
            SELECT Id, Name, LastModifiedDate
            FROM Opportunity
            WHERE LastModifiedDate >= :cutoffTime
            ORDER BY LastModifiedDate DESC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity opp : scope) {
            oppIds.add(opp.Id);
        }

        try {
            // Calculate tiers for this batch
            TierCalcService.calculateFor(oppIds, Date.today());
            totalProcessed += scope.size();
            System.debug('Successfully processed ' + scope.size() + ' opportunities in batch');
        } catch (Exception e) {
            totalErrors += scope.size();
            String errorMsg = 'Batch error: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString();
            errorMessages.add(errorMsg);
            System.debug(LoggingLevel.ERROR, errorMsg);

            // Log individual opportunity IDs that failed
            for (Opportunity opp : scope) {
                System.debug(LoggingLevel.ERROR, 'Failed Opportunity: ' + opp.Id + ' - ' + opp.Name);
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedDate, CompletedDate
            FROM AsyncApexJob
            WHERE Id = :bc.getJobId()
        ];

        String summary = 'Tier Calculation Batch Job Completed\n' +
                        '=====================================\n' +
                        'Job ID: ' + job.Id + '\n' +
                        'Status: ' + job.Status + '\n' +
                        'Total Batches: ' + job.TotalJobItems + '\n' +
                        'Processed Batches: ' + job.JobItemsProcessed + '\n' +
                        'Opportunities Processed: ' + totalProcessed + '\n' +
                        'Opportunities with Errors: ' + totalErrors + '\n' +
                        'Started: ' + job.CreatedDate + '\n' +
                        'Completed: ' + job.CompletedDate;

        if (!errorMessages.isEmpty()) {
            summary += '\n\nErrors:\n' + String.join(errorMessages, '\n');
        }

        System.debug(summary);

        // Optional: Send email notification if there were errors
        if (totalErrors > 0) {
            sendErrorNotification(job, summary);
        }
    }

    /**
     * Sends an email notification when errors occur
     */
    public void sendErrorNotification(AsyncApexJob job, String summary) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            // Use Org-Wide Email Address as sender to avoid domain authorization issues
            List<OrgWideEmailAddress> owas = [ SELECT Id FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = TRUE LIMIT 1 ];
            if (!owas.isEmpty()) {
                mail.setOrgWideEmailAddressId(owas[0].Id);
            }

            // Get recipient addresses from Apex Email Notification
            Set<String> recipientEmails = new Set<String>();
            List<ApexEmailNotification> notifications = [
                SELECT Email, User.Email, User.IsActive
                FROM ApexEmailNotification
                WHERE Email != NULL OR (UserId != NULL AND User.IsActive = true)
            ];

            for (ApexEmailNotification n : notifications) {
                if (n.Email != null) {
                    recipientEmails.add(n.Email);
                }
                if (n.User != null && n.User.IsActive && n.User.Email != null) {
                    recipientEmails.add(n.User.Email);
                }
            }

            if (recipientEmails.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'No active recipients found in Apex Email Notification, skipping error email');
                return;
            }

            mail.setToAddresses(new List<String>(recipientEmails));
            mail.setSubject('Tier Calculation Batch Job - Errors Detected');
            mail.setPlainTextBody(summary);

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to send error notification: ' + e.getMessage());
        }
    }

    public static String schedule(String jobName, String cronExpression) {
        return System.schedule(jobName, cronExpression, new TierCalcScheduledJob());
    }

    public static void abortAll() {
        for (CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE '%TierCalc%']) {
            System.abortJob(ct.Id);
        }
    }
}