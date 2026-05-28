@isTest
public class msft_SolutionTriggerTest {

    @isTest
    static void testAfterInsertAndDelete() {
        // Step 1: Create a test Opportunity
        Solution_Area__c solArea= new Solution_Area__c(
            Name= 'Test Sol Area1',
            Active__c= true
        );
        insert solArea;
        
        Solution_Play__c solPlay= new Solution_Play__c(
            Name= 'Test Sol Play1',
            Active__c= true,
            Solution_Area__c=solArea.Id
        );
        insert solPlay;
         
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Co_sell_Type__c='IP Co-sell',
            Solution_Area__c=solArea.Id,
            Solution_Play__c=solPlay.Id
        );
        insert opp;
        
        Microsoft_Solution_Detail__c solDetail1= new Microsoft_Solution_Detail__c(
            Name='Test MSFT Solution Detail 1',
            Solution_Identifier__c='000001',
            Type__c='1P',
            Publisher_Name__c='Microsoft'
        );
        insert solDetail1;
        
        // Step 2: Insert Microsoft_Solutions__c related to the opportunity
        Microsoft_Solutions__c sol1 = new Microsoft_Solutions__c(
            Solution__c = solDetail1.Id,
            Opportunity__c = opp.Id,
            Price__c= 100,
            Quantity__c= 10
        );
        Microsoft_Solutions__c sol2 = new Microsoft_Solutions__c(
            Solution__c = solDetail1.Id,
            Opportunity__c = opp.Id,
            Price__c= 500,
            Quantity__c= 20
        );
        insert new List<Microsoft_Solutions__c>{sol1, sol2};

        // Step 3: Query the updated Opportunity
        Opportunity updatedOpp = [SELECT Id, Solution_Count__c, Sync_With_Partner_Center__c 
                                  FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(2, updatedOpp.Solution_Count__c, 'Solution count should be 2');

        // Step 4: Delete one Microsoft_Solutions__c record
        delete sol1;

        // Step 5: Re-query and assert
        updatedOpp = [SELECT Id, Solution_Count__c, Sync_With_Partner_Center__c 
                      FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(1, updatedOpp.Solution_Count__c, 'Solution count should now be 1');

        // Step 6: Delete the last one
        delete sol2;

        updatedOpp = [SELECT Id, Solution_Count__c, Sync_With_Partner_Center__c 
                      FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(0, updatedOpp.Solution_Count__c, 'Solution count should be 0');
        System.assertEquals(false, updatedOpp.Sync_With_Partner_Center__c, 
                            'Sync_With_Partner_Center__c should be false when no solutions');
    }
}