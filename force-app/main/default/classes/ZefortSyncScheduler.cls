public with sharing class ZefortSyncScheduler implements Schedulable {
    public static final Integer MAX_REQUESTS_PER_RUN = 100;
    public static final Integer BATCH_SIZE = 20;

    public void execute(SchedulableContext context) {
        List<Id> candidateIds = ZefortSignService.listSyncCandidateRequestIds(
            MAX_REQUESTS_PER_RUN
        );
        if (candidateIds.isEmpty()) {
            return;
        }

        for (Integer index = 0; index < candidateIds.size(); index += BATCH_SIZE) {
            Integer endIndex = Math.min(index + BATCH_SIZE, candidateIds.size());
            List<Id> chunk = new List<Id>();
            for (Integer itemIndex = index; itemIndex < endIndex; itemIndex++) {
                chunk.add(candidateIds[itemIndex]);
            }
            System.enqueueJob(new ZefortSyncQueueable(new List<Id>(chunk)));
        }
    }
}