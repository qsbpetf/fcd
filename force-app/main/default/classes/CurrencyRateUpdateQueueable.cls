/**
 * Queueable class for updating currency conversion rates.
 * This class allows making API callouts to fetch exchange rates
 * and update Salesforce currency rates.
 *
 * It should be invoked from a schedulable class since
 * scheduled Apex cannot make callouts directly.
 */
public class CurrencyRateUpdateQueueable implements Queueable, Database.AllowsCallouts {

    private Boolean sendEmailOnError;
    private String notificationEmail;

    /**
     * Constructor with default settings
     */
    public CurrencyRateUpdateQueueable() {
        this(true, null);
    }

    /**
     * Constructor with custom error notification settings
     *
     * @param sendEmailOnError Whether to send an email when an error occurs
     * @param notificationEmail The email address to notify (if null, uses current user's email)
     */
    public CurrencyRateUpdateQueueable(Boolean sendEmailOnError, String notificationEmail) {
        this.sendEmailOnError = sendEmailOnError;
        this.notificationEmail = notificationEmail != null ? notificationEmail : UserInfo.getUserEmail();
    }

    /**
     * Execute method required by the Queueable interface.
     * This method will be called when the queueable job runs.
     *
     * @param context The QueueableContext provided by the system
     */
    public void execute(QueueableContext context) {
        try {
            // Log the start of the process
            System.debug(LoggingLevel.INFO, 'Starting queueable currency rate update');

            // Call the method to update currency conversion rates
            CurrencyCtrl.updateCurrencyConversionRates();

            // Log successful completion
            System.debug(LoggingLevel.INFO, 'Currency rate update completed successfully');
        } catch (Exception e) {
            // Log any errors that occur during the update
            System.debug(LoggingLevel.ERROR, 'Error updating currency rates: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());

            // Send an email notification about the failure if configured to do so
            if (sendEmailOnError) {
                sendErrorNotification(e);
            }
        }
    }

    /**
     * Sends an email notification when an error occurs during the currency update.
     *
     * @param e The exception that was caught
     */
    private void sendErrorNotification(Exception e) {
        try {
            // Create an email message
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            // Set the recipient to the configured email
            mail.setToAddresses(new String[] { notificationEmail });

            // Set email subject and body
            mail.setSubject('Error in Currency Rate Update Job');
            mail.setPlainTextBody(
                'An error occurred while updating currency conversion rates:\n\n' +
                'Error message: ' + e.getMessage() + '\n\n' +
                'Stack trace: ' + e.getStackTraceString()
            );

            // Send the email
            if (!Test.isRunningTest()) {
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
        } catch (Exception emailEx) {
            // If there's an error sending the email, just log it
            System.debug(LoggingLevel.ERROR, 'Error sending notification email: ' + emailEx.getMessage());
        }
    }
}