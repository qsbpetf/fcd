/* 
* @author Alan Abishev - Ceterna LTD
* @createddate 21/04/2017
* @edited 21/04/2017
*/


/*=============================================================================
//
//    After update trigger on Opportunity to convert OpportunityLineItems 
//    into Assets when StageName == 'Order'
//
/*=============================================================================*/

trigger triggerCreateAssets on Opportunity (after update) {
    
    //(new triggerCreateAssetsHandler()).execute();
}