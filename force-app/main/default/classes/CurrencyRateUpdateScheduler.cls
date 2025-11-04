/**
 * Schedulable class to update currency conversion rates on a regular basis.
 * This job can be scheduled to run daily to ensure currency rates are up to date.
 *
 * To schedule this job, use the following Apex code in Developer Console:
 * String cronExp = '0 0 1 * * ?'; // Run at 1 AM daily
 * String jobId = System.schedule('Daily Currency Update', cronExp, new CurrencyRateUpdateScheduler());
 */
public class CurrencyRateUpdateScheduler implements Schedulable {

    private Boolean sendEmailOnError;
    private String notificationEmail;

    /**
     * Default constructor
     */
    public CurrencyRateUpdateScheduler() {
        this(true, null);
    }

    /**
     * Constructor with custom error notification settings
     *
     * @param sendEmailOnError Whether to send an email when an error occurs
     * @param notificationEmail The email address to notify (if null, uses current user's email)
     */
    public CurrencyRateUpdateScheduler(Boolean sendEmailOnError, String notificationEmail) {
        this.sendEmailOnError = sendEmailOnError;
        this.notificationEmail = notificationEmail;
    }

    /**
     * Execute method required by the Schedulable interface.
     * This method will be called when the scheduled job runs.
     *
     * @param sc The SchedulableContext provided by the system
     */
    public void execute(SchedulableContext sc) {
        // Enqueue the queueable job to perform the callout
        System.enqueueJob(new CurrencyRateUpdateQueueable(sendEmailOnError, notificationEmail));
    }
}
