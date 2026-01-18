//  Apex for LWC / Quick Action
public with sharing class TierCalcController {
    public class LineDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String userName;
        @AuraEnabled public Decimal t1Amount;
        @AuraEnabled public Decimal t2Amount;
        @AuraEnabled public Decimal t3Amount;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime lastModified;
    }
    public class RecalcResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public List<LineDTO> lines;
    }

    @AuraEnabled(Cacheable=true)
    public static List<LineDTO> getTierLines(Id opportunityId) {
        Map<Id, User> users = new Map<Id, User>([
            SELECT Id, Name FROM User WHERE Id IN (
                SELECT User__c FROM Tier__c WHERE Opportunity__c = :opportunityId
            )
        ]);

        List<LineDTO> output = new List<LineDTO>();
        for (Tier__c cl : [
            SELECT Id, User__c, Status__c, LastModifiedDate, T1_Amount__c, T2_Amount__c, T3_Amount__c
            FROM Tier__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY LastModifiedDate DESC
        ]) {
            LineDTO d = new LineDTO();
            d.id = cl.Id;
            d.userName = (users.containsKey(cl.User__c) ? users.get(cl.User__c).Name : String.valueOf(cl.User__c));
            d.t1Amount = cl.T1_Amount__c;
            d.t2Amount = cl.T2_Amount__c;
            d.t3Amount = cl.T3_Amount__c;
            d.status = cl.Status__c;
            d.lastModified = cl.LastModifiedDate;
            output.add(d);
        }
        return output;
    }

    @AuraEnabled
    public static RecalcResult recalcNow(Id opportunityId) {
        TierCalcService.calculateFor(new Set<Id>{opportunityId}, Date.today());
        RecalcResult r = new RecalcResult();
        r.success = true;
        r.message = 'Calculation completed';
        r.lines = getTierLines(opportunityId);
        return r;
    }

    // Input wrapper for Flow
    public class FlowInput {
        @InvocableVariable(Required=true Label='Opportunity ID')
        public Id opportunityId;
    }

    // Output wrapper for Flow
    public class FlowOutput {
        @InvocableVariable(Label='Success')
        public Boolean success;
        @InvocableVariable(Label='Message')
        public String message;
        @InvocableVariable(Label='All Tier Lines')
        public List<LineDTO> lines;
        @InvocableVariable(Label='Total Tier Lines')
        public Integer lineCount;
    }

    @InvocableMethod(Label='Recalculate Tiers' Description='Recalculates tiers for an opportunity')
    public static List<FlowOutput> recalculateTiers(List<FlowInput> inputs) {
        List<FlowOutput> outputs = new List<FlowOutput>();

        for (FlowInput input : inputs) {
            FlowOutput output = new FlowOutput();
            try {
                TierCalcService.calculateFor(new Set<Id>{input.opportunityId}, Date.today());
                List<LineDTO> lines = getTierLines(input.opportunityId);
                output.success = true;
                output.message = 'Calculation completed';
                output.lines = lines;
                output.lineCount = lines.size();
            } catch (Exception e) {
                output.success = false;
                output.message = e.getMessage();
                output.lineCount = 0;
            }
            outputs.add(output);
        }
        return outputs;
    }

}