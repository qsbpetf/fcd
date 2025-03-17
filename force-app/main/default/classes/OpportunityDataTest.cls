/**
 * Created by peterfriberg on 2025-03-13.
 */

@IsTest
private class OpportunityDataTest {

    @IsTest
    static void testBehavior() {
        OpportunityData opportunityData = new OpportunityData();
        System.assertEquals(null, opportunityData.opptyId);
        System.assertEquals(null, opportunityData.stageName);
        System.assertNotEquals(null, opportunityData.lines);
    }

    @IsTest
    static void testBehaviorWithParams() {
        List<OpportunityLineItem> lines = new List<OpportunityLineItem>();
        OpportunityData opportunityData = new OpportunityData('opptyId', 'stageName', lines);
        System.assertEquals('opptyId', opportunityData.opptyId);
        System.assertEquals('stageName', opportunityData.stageName);
        System.assertEquals(lines, opportunityData.lines);
    }
}