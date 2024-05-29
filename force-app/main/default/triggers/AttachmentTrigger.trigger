Trigger AttachmentTrigger on Attachment (after insert) {  
    Map<String, Set<Id>> sObjectsByType = new Map<String, Set<Id>>();
    for(Attachment a : Trigger.new) {
        String sObjectType = String.valueOf(a.ParentId.getSObjectType());
        if (sObjectsByType.containsKey(sObjectType)) {
            sObjectsByType.get(sObjectType).add(a.ParentId);
        } else {
            sObjectsByType.put(sObjectType, new Set<Id>{a.ParentId});
        }
    }
    
    for(String sObjectType : sObjectsByType.keySet()) {
        Set<Id> ids = sObjectsByType.get(sObjectType);
        String sObjectsById = 'SELECT Id FROM ' + sObjectType + ' where Id IN :ids'; 
        List<SObject> toBePushed = Database.query(sObjectsById);
        JSFS.API.pushUpdatesToJira(toBePushed, Trigger.old);
    }
}