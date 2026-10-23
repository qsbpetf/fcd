public with sharing class ZefortSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> signRequestIds;

    public ZefortSyncQueueable(List<Id> signRequestIds) {
        this.signRequestIds = signRequestIds == null
            ? new List<Id>()
            : new List<Id>(signRequestIds);
    }

    public void execute(QueueableContext context) {
        if (this.signRequestIds == null || this.signRequestIds.isEmpty()) {
            return;
        }
        ZefortSignService.syncSignRequestIds(this.signRequestIds);
    }
}