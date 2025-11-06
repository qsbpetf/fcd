/**
 * Created by peterfriberg on 2025-03-11.
 */

public class ProcessOpportunityLinesQueueable implements Queueable {
    private static final Integer MAX_ITEMS_TO_PROCESS = 90;
    private final OpportunityData data;

    public ProcessOpportunityLinesQueueable(OpportunityData data) {
        this.data = data;
        System.debug('### ProcessOpportunityLinesQueueable constructor called with data: ' + data);
    }

    public void execute(QueueableContext context) {
        // If there are no items, exit
        if (data.lines == null || data.lines.isEmpty()) {
            System.debug('No opportunity line items to process.');
            return;
        }

        List<PendingInvoice__c> pendingInvoices = new List<PendingInvoice__c>([
            SELECT Id, Name, Status__c, Subsidiary__c, Error__c, Invoice_JSON__c, RetryCount__c, LineItemsInserted__c
            FROM PendingInvoice__c
            WHERE Id = :data.pendingInvoiceId]);

        if (pendingInvoices.isEmpty()) {
            System.debug('Pending invoice not found: ' + data.pendingInvoiceId);
            return;
        }
        PendingInvoice__c pendingInvoice = pendingInvoices[0];

        // Determine the number of items to process
        Integer itemsToProcess = Math.min(MAX_ITEMS_TO_PROCESS, data.lines.size());

        try {
            List<OpportunityLineItem> linesToInsert = new List<OpportunityLineItem>();
            // Process first two items
            for (Integer i = 0; i < itemsToProcess; i++) {
                OpportunityLineItem line = data.lines.remove(0);
                System.debug('Processing Line Item: ' + line);
                linesToInsert.add(line);
            }
            insert linesToInsert;

            // Update the pending invoice with the number of line items inserted
            pendingInvoice.LineItemsInserted__c += itemsToProcess;
            update pendingInvoice;
        } catch (Exception e) {
            pendingInvoice.Error__c = (pendingInvoice.Error__c != null ? pendingInvoice.Error__c : '') + e.getMessage() + '\n' + e.getStackTraceString();
            pendingInvoice.RetryCount__c = (pendingInvoice.RetryCount__c != null ? pendingInvoice.RetryCount__c : 0) + 1;
            pendingInvoice.Status__c = 'Error';
            update pendingInvoice;

            System.debug('Error processing opportunity line items: ' + e.getMessage() + e.getStackTraceString());

            if (pendingInvoice.RetryCount__c >= 4) {
                pendingInvoice.Status__c = 'Failed';
                update pendingInvoice;
                System.debug('Pending invoice has failed after 4 retries: ' + pendingInvoice.Id);
                return;
            }
        }

        // Check if there are remaining items
        if (data.lines.size() > 0) {
            // Create a new OpportunityData object with remaining items
            OpportunityData newData = new OpportunityData(data.opptyId, data.stageName, data.lines, data.pendingInvoiceId);

            System.debug('### Enqueueing next batch of opportunity line items. There are ' + data.lines.size() + ' items remaining.');
            // Enqueue the next batch
            String jobId = System.enqueueJob(new ProcessOpportunityLinesQueueable(newData));
            System.debug('### Next batch of opportunity line items enqueued. Job ID: ' + jobId);
        } else {
            System.debug('All opportunity line items processed.');
            if (pendingInvoice.Status__c != 'Error') {
                System.debug('Updating opportunity stage to: ' + data.stageName);
                Opportunity opportunity = new Opportunity(Id = data.opptyId, StageName = data.stageName);
                update opportunity;

                pendingInvoice.Status__c = 'Done';
                update pendingInvoice;
            }

            System.debug('Pending Invoice updated to Processed.');
        }
    }
}