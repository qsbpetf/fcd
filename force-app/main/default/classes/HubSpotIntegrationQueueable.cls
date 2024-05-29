public with sharing class HubSpotIntegrationQueueable implements Queueable, Database.AllowsCallouts {
    public static final String JOB_NAME = 'hubspot-account-hierarchy-integration-queueable';
    private static final Integer AMOUNT_TO_PROCESS = 40;

    public String parentLogTransactionId { get; set; }

    private List<HubSpotIntegration.FlowRequest> flowRequests;

    // This method is called from scheduled flow to process account records
    @InvocableMethod(label='HubSpot: Update account hierarchy (queueable)' description='Queueable logic to update Salesforce account hierarchy changes to HubSpot.' category='HubSpot' callout=true)
    public static void processAccountHierarchyUpdateWithQueueable(List<HubSpotIntegration.FlowRequest> flowRequests) {
        Logger.debug('Update account hierarchy in HubSpot with queueable - amount of accounts to process: ' + flowRequests.size());
        Logger.saveLog();

        HubSpotIntegrationQueueable job = new HubSpotIntegrationQueueable(flowRequests);
        job.parentLogTransactionId = Logger.getTransactionId();
        System.enqueueJob(job);
    }

    public HubSpotIntegrationQueueable(List<HubSpotIntegration.FlowRequest> flowRequests) {
        this.flowRequests = flowRequests;
    }

    public void execute(QueueableContext ctx) {
        if (this.parentLogTransactionId != null) {
            Logger.setParentLogTransactionId(this.parentLogTransactionId);
        }
        Logger.info(JOB_NAME + ' started - amount of hierarchy updates left to process: ' + this.flowRequests.size());

        List<HubSpotIntegration.FlowRequest> processList = new List<HubSpotIntegration.FlowRequest>();
        List<HubSpotIntegration.FlowRequest> nextJobList = new List<HubSpotIntegration.FlowRequest>();

        Integer maxAmount = Test.isRunningTest() ? 1 : AMOUNT_TO_PROCESS;
        Integer count = 0;
        for (HubSpotIntegration.FlowRequest fReq : this.flowRequests) {
            if (count < maxAmount) {
                processList.add(fReq);
            } else {
                nextJobList.add(fReq);
            }
            count++;
        }

        HubSpotIntegration hsi = new HubSpotIntegration(processList);
        hsi.updateAccountHierarchy();

        if (!nextJobList.isEmpty()) {
            HubSpotIntegrationQueueable job = new HubSpotIntegrationQueueable(nextJobList);
            job.parentLogTransactionId = Logger.getTransactionId();
            Id jobId = Test.isRunningTest() ? null : System.enqueueJob(job);
            Logger.debug('Unprocessed account hierarchy updates left to process, started new ' + JOB_NAME + ' with job id: ' + jobId);
        } else {
            Logger.info(JOB_NAME + ' finished (all hierarchy updates processed)');
        }

        Logger.saveLog();
    }
}