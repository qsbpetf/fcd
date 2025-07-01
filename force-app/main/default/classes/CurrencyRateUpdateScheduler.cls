/**
 * Created by peterfriberg on 2025-07-01.
 */

/**
 * Schedulable class to update currency conversion rates on a regular basis.
 * This job can be scheduled to run daily to ensure currency rates are up to date.
 *
 * To schedule this job, use the following Apex code in Developer Console:
 * String cronExp = '0 0 1 * * ?'; // Run at 1 AM daily
 * String jobId = System.schedule('Daily Currency Update', cronExp, new CurrencyRateUpdateScheduler());
 */
public class CurrencyRateUpdateScheduler implements Schedulable {

    /**
     * Execute method required by the Schedulable interface.
     * This method will be called when the scheduled job runs.
     *
     * @param sc The SchedulableContext provided by the system
     */
    public void execute(SchedulableContext sc) {
        // Call the method to update currency conversion rates
        updateCurrencyRates();
    }

    /**
     * Updates currency conversion rates by calling the static method
     * in CurrencyCtrl. This method can also be called directly for
     * immediate execution.
     */
    public static void updateCurrencyRates() {
        try {
            // Log the start of the process
            System.debug(LoggingLevel.INFO, 'Starting scheduled currency rate update');

            // Call the method to update currency conversion rates
            CurrencyCtrl.updateCurrencyConversionRates();

            // Log successful completion
            System.debug(LoggingLevel.INFO, 'Currency rate update completed successfully');
        } catch (Exception e) {
            // Log any errors that occur during the update
            System.debug(LoggingLevel.ERROR, 'Error updating currency rates: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack trace: ' + e.getStackTraceString());

            // Optionally, you could send an email notification about the failure
            sendErrorNotification(e);
        }
    }

    /**
     * Sends an email notification when an error occurs during the currency update.
     *
     * @param e The exception that was caught
     */
    private static void sendErrorNotification(Exception e) {
        try {
            // Create an email message
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

            // Set the recipient to the current user (or a specific admin email)
            mail.setToAddresses(new String[] { UserInfo.getUserEmail() });

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