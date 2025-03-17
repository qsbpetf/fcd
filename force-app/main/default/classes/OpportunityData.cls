/**
 * Created by peterfriberg on 2025-03-11.
 *
 * Represents the list of opportunity line items to create for the opportunity
 * Used as parameter for the queueable class ProcessOpportunityLinesQueueable
 * to create the opportunity line items in separate execution context.
 * This is needed due to there are many automations and integrations that
 * will execute on each line item inserted.
 */

public class OpportunityData {
    public String opptyId;
    public String stageName;
    public List<OpportunityLineItem> lines;

    public OpportunityData() {
        this.opptyId = null;
        this.stageName = null;
        this.lines = new List<OpportunityLineItem>();
    }

    public OpportunityData(String opptyId, String stageName, List<OpportunityLineItem> lines) {
        this.opptyId = opptyId;
        this.stageName = stageName;
        this.lines = lines;
    }
}