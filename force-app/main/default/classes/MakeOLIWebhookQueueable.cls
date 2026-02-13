public without sharing class MakeOLIWebhookQueueable implements Queueable, Database.AllowsCallouts {

    @TestVisible
    private static final String NAMED_CREDENTIAL = 'MakeDotCom';

    @TestVisible
    private static final String OLI_WEBHOOK_PATH = '/slapmx023cyfjtce3p7vcw8vvbgp6dyc';

    private final List<Id> opportunityLineItemIds;

    public MakeOLIWebhookQueueable(Set<Id> opportunityLineItemIds) {
        this(opportunityLineItemIds != null ? new List<Id>(opportunityLineItemIds) : new List<Id>());
    }

    public MakeOLIWebhookQueueable(List<Id> opportunityLineItemIds) {
        this.opportunityLineItemIds = opportunityLineItemIds != null ? new List<Id>(opportunityLineItemIds) : new List<Id>();
    }

    public void execute(QueueableContext context) {
        if (opportunityLineItemIds.isEmpty()) {
            return;
        }

        for (Id oliId : opportunityLineItemIds) {
            if (oliId == null) {
                continue;
            }

            try {
                sendOpportunityLineItemWebhook(oliId);
            } catch (Exception e) {
                System.debug('MakeOLIWebhookQueueable error for OpportunityLineItem ' + oliId + ': ' + e.getMessage());
            }
        }
    }

    @TestVisible
    private static void sendOpportunityLineItemWebhook(Id oliId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NAMED_CREDENTIAL + OLI_WEBHOOK_PATH);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> payload = new Map<String, Object>{
            'OpportunityLineItemId' => (String) oliId
        };
        req.setBody(JSON.serialize(payload));

        Http http = new Http();
        http.send(req);
    }
}