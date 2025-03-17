/**
 * Created by peterfriberg on 2025-03-11.
 */

public class ProcessOpportunityLinesQueueable implements Queueable {
    private static final Integer MAX_ITEMS_TO_PROCESS = 2;
    private final OpportunityData data;

    public ProcessOpportunityLinesQueueable(OpportunityData data) {
        this.data = data;
    }

    public void execute(QueueableContext context) {
        // If there are no items, exit
        if (data.lines == null || data.lines.isEmpty()) {
            System.debug('No opportunity line items to process.');
            return;
        }

        // Determine the number of items to process
        Integer itemsToProcess = Math.min(MAX_ITEMS_TO_PROCESS, data.lines.size());

        // Process first two items
        for (Integer i = 0; i < itemsToProcess; i++) {
            OpportunityLineItem line = data.lines.remove(0);
            System.debug('Processing Line Item: ' + line);
            insert line;
        }

        // Check if there are remaining items
        if (data.lines.size() > 0) {
            // Create a new OpportunityData object with remaining items
            OpportunityData newData = new OpportunityData(data.opptyId, data.stageName, data.lines);

            System.debug('### Enqueueing next batch of opportunity line items. There are ' + data.lines.size() + ' items remaining.');
            // Enqueue the next batch
            String jobId = System.enqueueJob(new ProcessOpportunityLinesQueueable(newData));
            System.debug('### Next batch of opportunity line items enqueued. Job ID: ' + jobId);
        } else {
            System.debug('All opportunity line items processed.');
            System.debug('Updating opportunity stage to: ' + data.stageName);
            Opportunity opportunity = new Opportunity(Id = data.opptyId, StageName = data.stageName);
            update opportunity;
        }
    }
}