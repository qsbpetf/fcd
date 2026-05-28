/**
 * Unit tests for OppSplitService utility methods.
 *
 * Tests the building blocks of the split automation in isolation:
 *   - buildKey (2-arg and 3-arg)
 *   - isAutomationEnabled / tryEnterAutomation / resetAutomationFlag
 *   - addSplitIfMissing + getExistingSplitKeys + getSplits (dedup logic)
 *   - createStandardSplits (opp owner + account owner splits)
 *
 * Renamed from OppSplitHandlerTest (Step 1 of the OppSplit optimization plan).
 * For full trigger-level lifecycle coverage see OppSplitE2ETest.
 */
@IsTest
private class OppSplitServiceTest {

	@TestSetup
	static void makeData() {
		TestDataFactory.setAutomation(false);

		SObject oppOwner = TestDataFactory.createTestUser('osshoo@osshandlertest.invalid', 'SvcOppOwner', 'osshoo');
		SObject accOwner = TestDataFactory.createTestUser('osshao@osshandlertest.invalid', 'SvcAccOwner', 'osshao');
		insert new List<SObject>{ oppOwner, accOwner };

		insert TestDataFactory.getAccount('SvcTestAccount', getUserIdByLastName('SvcAccOwner'), Date.newInstance(2025, 1, 1));
	}

	private static Id getUserIdByLastName(String lastName) {
		SObject userRecord = [SELECT Id FROM User WHERE LastName = :lastName LIMIT 1];
		return (Id) userRecord.get('Id');
	}

	private static Id getOppOwnerId() {
		return getUserIdByLastName('SvcOppOwner');
	}

	private static Id getAccOwnerId() {
		return getUserIdByLastName('SvcAccOwner');
	}

	private static Account getAccount() {
		return [SELECT Id, OwnerId FROM Account WHERE Name = 'SvcTestAccount' LIMIT 1];
	}

	private static Opportunity insertOpp(Id accId, Id ownerId) {
		Opportunity opp = TestDataFactory.getOpp(
			accId,
			ownerId,
			Date.newInstance(2026, 12, 31),
			'Explore',
			null,
			'SvcTestOpp ' + String.valueOf(Crypto.getRandomInteger())
		);
		insert opp;
		return opp;
	}

	private static void setAutomation(Boolean isEnabled) {
		TestDataFactory.setAutomation(isEnabled);
		OppSplitService.clearAutomationSettingsCache();
	}

	private static Id getSplitTypeId(String label) {
		List<OpportunitySplitType> types = [
			SELECT Id
			FROM OpportunitySplitType
			WHERE MasterLabel = :label
			LIMIT 1
		];
		return types.isEmpty() ? null : types[0].Id;
	}

	@IsTest
	static void buildKey_methodsReturnExpectedValues() {
		Id oppId = '006000000000001AAA';
		Id userId = '005000000000001AAA';
		Id typeId = '0XA000000000001AAA';

		System.assertEquals(oppId + '_' + userId,
			OppSplitService.buildKey(oppId, userId),
			'Two-argument buildKey should join opportunity and owner ids.');
		System.assertEquals(oppId + '_' + userId + '_' + typeId,
			OppSplitService.buildKey(oppId, userId, typeId),
			'Three-argument buildKey should join opportunity, owner, and split type ids.');
	}

	@IsTest
	static void automationHelpers_respectOrgDefaultsAndResetFlag() {
		setAutomation(false);
		System.assertEquals(false, OppSplitService.isAutomationEnabled(),
			'Automation should be disabled after updating the org defaults.');

		setAutomation(true);
		System.assertEquals(true, OppSplitService.isAutomationEnabled(),
			'Automation should be enabled after updating the org defaults.');

		System.assertEquals(true, OppSplitService.tryEnterAutomation(),
			'The first recursion-guard entry should succeed.');
		System.assertEquals(false, OppSplitService.tryEnterAutomation(),
			'The recursion guard should block re-entry until reset.');
		OppSplitService.resetAutomationFlag();
		System.assertEquals(true, OppSplitService.tryEnterAutomation(),
			'Resetting the recursion guard should allow entry again.');
	}

	@IsTest
	static void addSplitIfMissing_andSplitQueries_deduplicateCorrectly() {
		Id t1TypeId = getSplitTypeId('T1');

		Account acc = getAccount();
		Id oppOwnerId = getOppOwnerId();
		Opportunity opp = insertOpp(acc.Id, oppOwnerId);

		List<OpportunitySplit> pendingSplits = new List<OpportunitySplit>();
		Set<String> existingKeys = new Set<String>();

		OppSplitService.addSplitIfMissing(pendingSplits, existingKeys, opp.Id, oppOwnerId, t1TypeId);
		OppSplitService.addSplitIfMissing(pendingSplits, existingKeys, opp.Id, oppOwnerId, t1TypeId);

		System.assertEquals(1, pendingSplits.size(),
			'addSplitIfMissing should only add the first split for a given key.');

		insert pendingSplits;

		// Replaced OppSplitService.getExistingSplitKeys with manual query as the service method was removed during optimization
		Set<String> queriedKeys = new Set<String>();
		for (OpportunitySplit s : [SELECT OpportunityId, SplitOwnerId, SplitTypeId FROM OpportunitySplit WHERE OpportunityId = :opp.Id AND SplitTypeId = :t1TypeId]) {
			queriedKeys.add(OppSplitService.buildKey(s.OpportunityId, s.SplitOwnerId, s.SplitTypeId));
		}
		List<OpportunitySplit> queriedSplits = OppSplitService.getSplits(new Set<Id>{ opp.Id }, new Set<Id>{ t1TypeId });

		System.assertEquals(1, queriedKeys.size(), 'One existing split key should be returned.');
		System.assertEquals(1, queriedSplits.size(), 'One matching split should be returned by getSplits.');
	}

	@IsTest
	static void createStandardSplits_addsOppOwnerAndAccountOwnerWhenDifferent() {
		Id t2TypeId = getSplitTypeId('T2');

		Account acc = getAccount();
		Id oppOwnerId = getOppOwnerId();
		Id accOwnerId = getAccOwnerId();
		Opportunity opp = insertOpp(acc.Id, oppOwnerId);
		Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
			SELECT Id, OwnerId, AccountId, T1_Opp__c, Total_Amount_T2__c, Total_Amount_T3__c,
			       CloseDate, Run_Splits_Flow__c, Net_Revenue_Forecast__c,
			       Estimate_Managed_Service_Revenue__c, Estimate_Licensing_Revenue__c,
			       T3_From_Products__c, Quota_Update_Allowed__c,
			       Account.OwnerId, Account.T1_Start_Date__c
			FROM Opportunity
			WHERE Id = :opp.Id
		]);
		List<OpportunitySplit> pendingSplits = new List<OpportunitySplit>();
		Set<String> existingKeys = new Set<String>();

		OppSplitService.createStandardSplits(
			pendingSplits,
			oppMap,
			new List<Id>{ opp.Id },
			t2TypeId,
			existingKeys
		);

		System.assertEquals(2, pendingSplits.size(),
			'createStandardSplits should create both opp-owner and account-owner splits when owners differ.');

		insert pendingSplits;

		System.assertEquals(1,
			[SELECT COUNT() FROM OpportunitySplit WHERE OpportunityId = :opp.Id AND SplitTypeId = :t2TypeId AND SplitOwnerId = :oppOwnerId],
			'An opportunity-owner split should be inserted.');
		System.assertEquals(1,
			[SELECT COUNT() FROM OpportunitySplit WHERE OpportunityId = :opp.Id AND SplitTypeId = :t2TypeId AND SplitOwnerId = :accOwnerId],
			'An account-owner split should be inserted.');
	}
}