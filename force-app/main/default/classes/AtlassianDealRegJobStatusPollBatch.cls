/**
 * Batch job that polls the Atlassian Deal Registration API for job status
 * on records with Job_Id__c and Status__c = 'IN_PROGRESS'.
 * Updates Status__c, Last_Polled__c, and Error__c when COMPLETED or FAILED.
 */
public with sharing class AtlassianDealRegJobStatusPollBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private static final Integer BATCH_SIZE = 10;
    private static final String STATUS_IN_PROGRESS = 'IN_PROGRESS';

    public static void run() {
        Database.executeBatch(new AtlassianDealRegJobStatusPollBatch(), BATCH_SIZE);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Job_Id__c, Partner_Account_Id__c, Status__c, Error__c
            FROM AtlassianDealRegSubmission__c
            WHERE Job_Id__c != null
            AND Partner_Account_Id__c != null
            AND Status__c = :STATUS_IN_PROGRESS
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<AtlassianDealRegSubmission__c> toUpdate = new List<AtlassianDealRegSubmission__c>();
        AtlassianDealRegApiRegistrations svc = AtlassianDealRegApiRegistrations.getInstance();

        for (SObject rec : scope) {
            AtlassianDealRegSubmission__c sub = (AtlassianDealRegSubmission__c) rec;
            try {
                AtlassianDealRegApiRegistrations.JobStatusSuccess result = svc.getJobStatus(
                    sub.Partner_Account_Id__c,
                    sub.Job_Id__c
                );

                sub.Status__c = result.status;
                sub.Last_Polled__c = Datetime.now();
                if (result.error != null) {
                    sub.Error__c = String.valueOf(result.error);
                } else if (String.isNotBlank(sub.Error__c) && (result.status == 'COMPLETED' || result.status == 'SUCCESS')) {
                    sub.Error__c = null;
                }
                toUpdate.add(sub);
            } catch (AtlassianDealRegApiClient.AtlassianDealRegApiException e) {
                sub.Error__c = e.getMessage();
                sub.Last_Polled__c = Datetime.now();
                toUpdate.add(sub);
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {
    }
}
