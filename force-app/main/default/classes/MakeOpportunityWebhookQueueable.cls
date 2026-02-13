public without sharing class MakeOpportunityWebhookQueueable implements Queueable, Database.AllowsCallouts {

    @TestVisible
    private static final String NAMED_CREDENTIAL = 'MakeDotCom';

    @TestVisible
    private static final String OPPORTUNITY_WEBHOOK_PATH = '/12mxoxjn4h43gaho9eo1r84xuwl6p5lj';

    private final List<Id> opportunityIds;

    public MakeOpportunityWebhookQueueable(Set<Id> opportunityIds) {
        this(opportunityIds != null ? new List<Id>(opportunityIds) : new List<Id>());
    }

    public MakeOpportunityWebhookQueueable(List<Id> opportunityIds) {
        this.opportunityIds = opportunityIds != null ? new List<Id>(opportunityIds) : new List<Id>();
    }

    public void execute(QueueableContext context) {
        if (opportunityIds.isEmpty()) {
            return;
        }

        for (Id oppId : opportunityIds) {
            if (oppId == null) {
                continue;
            }

            try {
                sendOpportunityWebhook(oppId);
            } catch (Exception e) {
                System.debug('MakeOpportunityWebhookQueueable error for Opportunity ' + oppId + ': ' + e.getMessage());
            }
        }
    }

    @TestVisible
    private static void sendOpportunityWebhook(Id oppId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + OPPORTUNITY_WEBHOOK_PATH);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> payload = new Map<String, Object>{
            'OpportunityId' => (String) oppId
        };
        req.setBody(JSON.serialize(payload));

        Http http = new Http();
        http.send(req);
    }
}

