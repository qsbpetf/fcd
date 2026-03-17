/**
 * Schedulable to run AtlassianDealRegJobStatusPollBatch hourly.
 *
 * To schedule:
 *   System.schedule('Atlassian Deal Reg Job Status Poll', '0 0 * * * ?', new AtlassianDealRegJobStatusPollScheduler());
 */
public with sharing class AtlassianDealRegJobStatusPollScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        AtlassianDealRegJobStatusPollBatch.run();
    }
}
