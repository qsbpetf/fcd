/**
 * Tests deliberately use STANDARD Opportunity fields (Description, NextStep,
 * Amount) and the Closing stage. Custom fields such as Total_Amount_Consulting__c
 * are formula or roll-up fields that cannot be set in test data, and the
 * Closed Won stages are guarded by the org's own validation rules, so anchoring
 * the tests there would make them fail for reasons unrelated to this code.
 */
@isTest
private class OpportunityReadinessServiceTest {

    private static final String STAGE_EARLY = 'Justify';
    private static final String STAGE_GUARDED = 'Closing';
    private static final String REQUIRED = 'Description;NextStep';

    // ---------------------------------------------------------------- helpers

    private static Opportunity_Readiness_Rule__mdt rule(String stages, String severity) {
        return new Opportunity_Readiness_Rule__mdt(
            DeveloperName = 'Test_Rule',
            MasterLabel = 'Test Rule',
            Active__c = true,
            Sequence__c = 10,
            Severity__c = severity,
            Target_Stages__c = stages,
            Primary_Amount_Operator__c = 'Any',
            Secondary_Amount_Operator__c = 'Any',
            Subsidiary_Scope__c = 'Any',
            Skip_When_Extension__c = false,
            Required_Fields__c = REQUIRED,
            Error_Message__c = 'Mandatory fields are missing.',
            Guidance__c = 'Fill these in to continue.'
        );
    }

    private static Opportunity newOpportunity(String name) {
        Account acct = new Account(Name = name + ' Acct');
        insert acct;
        Opportunity opp = new Opportunity(
            Name = name,
            AccountId = acct.Id,
            StageName = STAGE_EARLY,
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        return opp;
    }

    /**
     * Flips the engine's own switch instead of the org's custom settings.
     * Validation_Rule_Enabled__c gates every validation rule in this org, so
     * enabling it here would activate unrelated rules on the Closing stage.
     */
    private static void enableAutomation(Boolean enabled) {
        OpportunityReadinessService.automationOverride = enabled;
    }

    // ---------------------------------------------------------------- service

    @isTest
    static void listsEveryMissingFieldForAnInScopeRule() {
        Opportunity opp = newOpportunity('Readiness Gaps');
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Blocking') };

        Test.startTest();
        OpportunityReadinessService.Result result =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(false, result.isReady, 'Blank required fields should not be ready.');
        System.assertEquals(1, result.blocking.size(), 'One rule should block.');
        System.assertEquals(2, result.fieldsToFill.size(), 'Both blank fields should be listed.');
        System.assertEquals(2, result.requiredFieldCount, 'Two fields are required.');
        System.assertEquals(0, result.filledFieldCount, 'Neither field is filled.');
    }

    @isTest
    static void reportsReadyWhenEveryFieldIsFilled() {
        Opportunity opp = newOpportunity('Readiness Complete');
        opp.Description = 'Filled in';
        opp.NextStep = 'Send contract';
        update opp;

        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Blocking') };

        Test.startTest();
        OpportunityReadinessService.Result result =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(true, result.isReady, 'A complete record should be ready.');
        System.assertEquals(0, result.fieldsToFill.size(), 'Nothing should be missing.');
        System.assertEquals(2, result.filledFieldCount, 'Both fields count as filled.');
    }

    @isTest
    static void skipsRuleWhenStageIsNotGuarded() {
        Opportunity opp = newOpportunity('Readiness Wrong Stage');
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Blocking') };

        Test.startTest();
        OpportunityReadinessService.Result result =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_EARLY);
        Test.stopTest();

        System.assertEquals(true, result.isReady, 'A rule scoped elsewhere must not fire.');
        System.assertEquals(0, result.blocking.size(), 'No rule should block.');
    }

    @isTest
    static void warningNeverBlocks() {
        Opportunity opp = newOpportunity('Readiness Warning');
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Warning') };

        Test.startTest();
        OpportunityReadinessService.Result result =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(true, result.isReady, 'A warning must leave the record ready.');
        System.assertEquals(0, result.blocking.size(), 'A warning must not block.');
        System.assertEquals(1, result.warnings.size(), 'The warning should be reported.');
        System.assertEquals(2, result.fieldsToFill.size(), 'Warnings still list their fields.');
    }

    @isTest
    static void amountOperatorNarrowsScope() {
        Opportunity opp = newOpportunity('Readiness Amount');
        opp.Amount = 0;
        update opp;

        Opportunity_Readiness_Rule__mdt r = rule(STAGE_GUARDED, 'Blocking');
        r.Primary_Amount_Field__c = 'Amount';
        r.Primary_Amount_Operator__c = 'GreaterThanZero';
        OpportunityReadinessService.ruleOverride = new List<Opportunity_Readiness_Rule__mdt>{ r };

        Test.startTest();
        OpportunityReadinessService.Result zeroAmount =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);

        opp.Amount = 500;
        update opp;
        OpportunityReadinessService.Result withAmount =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(true, zeroAmount.isReady, 'A zero amount falls outside the rule.');
        System.assertEquals(false, withAmount.isReady, 'A positive amount brings it in scope.');
    }

    // ---------------------------------------------------------------- trigger

    @isTest
    static void triggerBlocksTheSaveWhenFieldsAreMissing() {
        Opportunity opp = newOpportunity('Readiness Blocked');
        enableAutomation(true);
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Blocking') };

        Boolean blocked = false;
        Test.startTest();
        try {
            opp.StageName = STAGE_GUARDED;
            update opp;
        } catch (DmlException e) {
            blocked = true;
        }
        Test.stopTest();

        System.assertEquals(true, blocked, 'The stage change should have been rejected.');
    }

    @isTest
    static void triggerHonoursBypass() {
        Opportunity opp = newOpportunity('Readiness Bypass');
        enableAutomation(true);
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Blocking') };
        OpportunityReadinessTriggerHandler.bypass = true;

        Test.startTest();
        opp.StageName = STAGE_GUARDED;
        update opp;
        Test.stopTest();

        System.assertEquals(
            STAGE_GUARDED,
            [SELECT StageName FROM Opportunity WHERE Id = :opp.Id].StageName,
            'Bypass should let the update through.'
        );
    }

    @isTest
    static void killSwitchStopsTheTrigger() {
        Opportunity opp = newOpportunity('Readiness Switch Off');
        enableAutomation(false);
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Blocking') };

        Test.startTest();
        opp.StageName = STAGE_GUARDED;
        update opp;
        Test.stopTest();

        System.assertEquals(
            STAGE_GUARDED,
            [SELECT StageName FROM Opportunity WHERE Id = :opp.Id].StageName,
            'With automation disabled the trigger should stand down.'
        );
    }

    // ---------------------------------------------------------------- controller

    @isTest
    static void controllerReturnsResultAndStages() {
        Opportunity opp = newOpportunity('Readiness Controller');
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Blocking') };

        Test.startTest();
        OpportunityReadinessService.Result result =
            OpportunityReadinessController.check(opp.Id, STAGE_GUARDED);
        List<Map<String, String>> stages = OpportunityReadinessController.closingStages();
        Test.stopTest();

        System.assertEquals(false, result.isReady, 'The controller should report the gaps.');
        System.assertNotEquals(null, stages, 'Stage options should be returned.');
    }

    @isTest
    static void saveAndAdvanceWritesFieldsAndStage() {
        Opportunity opp = newOpportunity('Readiness Save');
        enableAutomation(true);
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Blocking') };

        Test.startTest();
        OpportunityReadinessController.saveAndAdvance(
            opp.Id,
            new Map<String, Object>{ 'Description' => 'Filled', 'NextStep' => 'Sign' },
            STAGE_GUARDED
        );
        Test.stopTest();

        Opportunity saved = [
            SELECT StageName, Description, NextStep FROM Opportunity WHERE Id = :opp.Id
        ];
        System.assertEquals(STAGE_GUARDED, saved.StageName, 'The stage should have moved.');
        System.assertEquals('Filled', saved.Description, 'The field should have been written.');
        System.assertEquals('Sign', saved.NextStep, 'The field should have been written.');
    }

    @isTest
    static void saveAndAdvanceSurfacesTheBlockAsAnAuraError() {
        Opportunity opp = newOpportunity('Readiness Save Blocked');
        enableAutomation(true);
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Blocking') };

        Boolean threw = false;
        Test.startTest();
        try {
            OpportunityReadinessController.saveAndAdvance(
                opp.Id, new Map<String, Object>(), STAGE_GUARDED
            );
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Advancing with gaps should raise an error.');
    }

    // ------------------------------------------------- scoping branch coverage

    @isTest
    static void recordTypeGateKeepsRuleOutOfScope() {
        Opportunity opp = newOpportunity('Readiness RecordType');
        Opportunity_Readiness_Rule__mdt r = rule(STAGE_GUARDED, 'Blocking');
        r.Netsuite_Record_Type__c = 'Project';
        OpportunityReadinessService.ruleOverride = new List<Opportunity_Readiness_Rule__mdt>{ r };

        Test.startTest();
        OpportunityReadinessService.Result result =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(true, result.isReady, 'A record of another type is out of scope.');
    }

    @isTest
    static void effectiveFromCutoffGatesTheRule() {
        Opportunity opp = newOpportunity('Readiness Cutoff');

        Opportunity_Readiness_Rule__mdt older = rule(STAGE_GUARDED, 'Blocking');
        older.Effective_Date_Field__c = 'CloseDate';
        older.Effective_From__c = Date.today().addDays(-10);
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ older };

        Test.startTest();
        OpportunityReadinessService.Result inScope =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);

        Opportunity_Readiness_Rule__mdt future = rule(STAGE_GUARDED, 'Blocking');
        future.Effective_Date_Field__c = 'CloseDate';
        future.Effective_From__c = Date.today().addDays(90);
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ future };
        OpportunityReadinessService.Result outOfScope =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(false, inScope.isReady, 'A past cutoff keeps the rule active.');
        System.assertEquals(true, outOfScope.isReady, 'A future cutoff grandfathers the record.');
    }

    @isTest
    static void blankEffectiveDateFollowsItsSetting() {
        Opportunity opp = newOpportunity('Readiness Blank Date');

        // Description holds text, so the date parse fails and the value reads as blank.
        Opportunity_Readiness_Rule__mdt strict = rule(STAGE_GUARDED, 'Blocking');
        strict.Effective_Date_Field__c = 'Description';
        strict.Effective_From__c = Date.today().addDays(-10);
        strict.Treat_Blank_Effective_Date_As_In_Scope__c = false;
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ strict };

        Test.startTest();
        OpportunityReadinessService.Result skipped =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);

        Opportunity_Readiness_Rule__mdt lenient = rule(STAGE_GUARDED, 'Blocking');
        lenient.Effective_Date_Field__c = 'Description';
        lenient.Effective_From__c = Date.today().addDays(-10);
        lenient.Treat_Blank_Effective_Date_As_In_Scope__c = true;
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ lenient };
        OpportunityReadinessService.Result included =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(true, skipped.isReady, 'A blank date falls outside by default.');
        System.assertEquals(false, included.isReady, 'The lenient setting pulls it back in.');
    }

    @isTest
    static void secondaryAmountOperatorIsApplied() {
        Opportunity opp = newOpportunity('Readiness Secondary');
        opp.Amount = 250;
        update opp;

        Opportunity_Readiness_Rule__mdt r = rule(STAGE_GUARDED, 'Blocking');
        r.Secondary_Amount_Field__c = 'Amount';
        r.Secondary_Amount_Operator__c = 'EqualsZero';
        OpportunityReadinessService.ruleOverride = new List<Opportunity_Readiness_Rule__mdt>{ r };

        Test.startTest();
        OpportunityReadinessService.Result result =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(true, result.isReady, 'A non-zero amount fails the EqualsZero test.');
    }

    @isTest
    static void subsidiaryScopeReadsBothSources() {
        Opportunity opp = newOpportunity('Readiness Subsidiary');

        Opportunity_Readiness_Rule__mdt fromOpp = rule(STAGE_GUARDED, 'Blocking');
        fromOpp.Subsidiary_Scope__c = 'Non_UK_US';
        fromOpp.Subsidiary_Source__c = 'Opportunity';
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ fromOpp };

        Test.startTest();
        OpportunityReadinessService.Result nonUkUs =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);

        Opportunity_Readiness_Rule__mdt fromAccount = rule(STAGE_GUARDED, 'Blocking');
        fromAccount.Subsidiary_Scope__c = 'UK_US';
        fromAccount.Subsidiary_Source__c = 'Account';
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ fromAccount };
        OpportunityReadinessService.Result ukUs =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(false, nonUkUs.isReady, 'A blank subsidiary counts as non UK/US.');
        System.assertEquals(true, ukUs.isReady, 'A blank subsidiary is not UK or US.');
    }

    @isTest
    static void extensionOptOutIsHonoured() {
        Opportunity opp = newOpportunity('Readiness Extension');
        Opportunity_Readiness_Rule__mdt r = rule(STAGE_GUARDED, 'Blocking');
        r.Skip_When_Extension__c = true;
        OpportunityReadinessService.ruleOverride = new List<Opportunity_Readiness_Rule__mdt>{ r };

        Test.startTest();
        OpportunityReadinessService.Result result =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(false, result.isReady,
            'A record that is not an extension still falls under the rule.');
    }

    @isTest
    static void unknownAndBlankFieldListsAreTolerated() {
        Opportunity opp = newOpportunity('Readiness Odd Config');

        Opportunity_Readiness_Rule__mdt noFields = rule(STAGE_GUARDED, 'Blocking');
        noFields.Required_Fields__c = null;
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ noFields };

        Test.startTest();
        OpportunityReadinessService.Result empty =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);

        Opportunity_Readiness_Rule__mdt unknown = rule(STAGE_GUARDED, 'Blocking');
        unknown.Required_Fields__c = 'No_Such_Field__c;Description';
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ unknown };
        OpportunityReadinessService.Result mixed =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(true, empty.isReady, 'A rule with no fields cannot block.');
        System.assertEquals(false, mixed.isReady, 'The real field is still checked.');
    }

    @isTest
    static void nonNumericAmountFieldIsTreatedAsZero() {
        Opportunity opp = newOpportunity('Readiness Bad Amount');
        Opportunity_Readiness_Rule__mdt r = rule(STAGE_GUARDED, 'Blocking');
        r.Primary_Amount_Field__c = 'Description';
        r.Primary_Amount_Operator__c = 'EqualsZero';
        OpportunityReadinessService.ruleOverride = new List<Opportunity_Readiness_Rule__mdt>{ r };

        Test.startTest();
        OpportunityReadinessService.Result result =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(false, result.isReady,
            'An unparseable amount reads as zero, so EqualsZero matches.');
    }

    @isTest
    static void emptyInputReturnsEmptyResult() {
        Test.startTest();
        Map<Id, OpportunityReadinessService.Result> none =
            OpportunityReadinessService.evaluate(new Set<Id>(), null);
        Map<Id, OpportunityReadinessService.Result> nullSet =
            OpportunityReadinessService.evaluate(null, null);
        Test.stopTest();

        System.assertEquals(0, none.size(), 'An empty set yields no results.');
        System.assertEquals(0, nullSet.size(), 'A null set yields no results.');
    }

    @isTest
    static void inactiveRulesAreIgnoredByTheRealQuery() {
        Opportunity opp = newOpportunity('Readiness Real Rules');

        Test.startTest();
        List<Opportunity_Readiness_Rule__mdt> live = OpportunityReadinessService.rules();
        OpportunityReadinessService.Result result =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_EARLY);
        Test.stopTest();

        for (Opportunity_Readiness_Rule__mdt r : live) {
            System.assertEquals(true, r.Active__c, 'Only active rules should be returned.');
        }
        System.assertEquals(true, result.isReady, 'No deployed rule guards the early stage.');
    }

    // ------------------------------------------------- narrowed trigger checks

    /** Parks an incomplete opportunity in the guarded stage with the gate off. */
    private static Opportunity parkIncompleteInGuardedStage(String name) {
        Opportunity opp = newOpportunity(name);
        OpportunityReadinessTriggerHandler.bypass = true;
        opp.StageName = STAGE_GUARDED;
        update opp;
        OpportunityReadinessTriggerHandler.bypass = false;
        return opp;
    }

    @isTest
    static void unrelatedEditInGuardedStagePasses() {
        Opportunity opp = parkIncompleteInGuardedStage('Readiness Unrelated Edit');
        enableAutomation(true);
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Blocking') };

        Test.startTest();
        opp.Amount = 750;
        update opp;
        Test.stopTest();

        System.assertEquals(
            750,
            [SELECT Amount FROM Opportunity WHERE Id = :opp.Id].Amount,
            'An edit that neither moves the stage nor clears a required field should pass.'
        );
    }

    @isTest
    static void clearingARequiredFieldIsBlocked() {
        Opportunity opp = newOpportunity('Readiness Clear Field');
        opp.Description = 'Filled';
        opp.NextStep = 'Sign';
        update opp;

        enableAutomation(true);
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Blocking') };
        opp.StageName = STAGE_GUARDED;
        update opp;

        Boolean blocked = false;
        Test.startTest();
        try {
            opp.Description = null;
            update opp;
        } catch (DmlException e) {
            blocked = true;
        }
        Test.stopTest();

        System.assertEquals(true, blocked, 'Emptying a required field in a guarded stage must fail.');
    }

    @isTest
    static void bypassPermissionSkipsTheCheck() {
        Opportunity opp = newOpportunity('Readiness Bypass Permission');
        enableAutomation(true);
        OpportunityReadinessService.ruleOverride =
            new List<Opportunity_Readiness_Rule__mdt>{ rule(STAGE_GUARDED, 'Blocking') };
        OpportunityReadinessTriggerHandler.bypassPermissionOverride = true;

        Test.startTest();
        opp.StageName = STAGE_GUARDED;
        update opp;
        Test.stopTest();

        System.assertEquals(
            STAGE_GUARDED,
            [SELECT StageName FROM Opportunity WHERE Id = :opp.Id].StageName,
            'A user holding the bypass permission should pass.'
        );
    }

    @isTest
    static void unknownRequiredFieldIsIgnoredWhenComparing() {
        Opportunity before = new Opportunity(Description = 'x');
        Opportunity after = new Opportunity(Description = 'x');

        Test.startTest();
        Boolean cleared = OpportunityReadinessTriggerHandler.clearedARequiredField(
            after, before, new Set<String>{ 'No_Such_Field__c', 'Description' }
        );
        Boolean noPrior = OpportunityReadinessTriggerHandler.clearedARequiredField(
            after, null, new Set<String>{ 'Description' }
        );
        Test.stopTest();

        System.assertEquals(false, cleared, 'Unknown fields are skipped and Description is unchanged.');
        System.assertEquals(false, noPrior, 'Without a prior version nothing was cleared.');
    }

    @isTest
    static void anyAmountMatchNeedsOnlyOneCondition() {
        Opportunity opp = newOpportunity('Readiness Any Amount');
        opp.Amount = 500;
        update opp;

        // Amount > 0 holds; Description (blank, reads as 0) > 0 does not.
        Opportunity_Readiness_Rule__mdt anyRule = rule(STAGE_GUARDED, 'Blocking');
        anyRule.Primary_Amount_Field__c = 'Amount';
        anyRule.Primary_Amount_Operator__c = 'GreaterThanZero';
        anyRule.Secondary_Amount_Field__c = 'Description';
        anyRule.Secondary_Amount_Operator__c = 'GreaterThanZero';
        anyRule.Amount_Match__c = 'Any';

        Opportunity_Readiness_Rule__mdt allRule = anyRule.clone();
        allRule.Amount_Match__c = 'All';

        Test.startTest();
        OpportunityReadinessService.ruleOverride = new List<Opportunity_Readiness_Rule__mdt>{ anyRule };
        OpportunityReadinessService.Result withAny =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        OpportunityReadinessService.ruleOverride = new List<Opportunity_Readiness_Rule__mdt>{ allRule };
        OpportunityReadinessService.Result withAll =
            OpportunityReadinessService.evaluateOne(opp.Id, STAGE_GUARDED);
        Test.stopTest();

        System.assertEquals(false, withAny.isReady, 'Any: one matching amount brings the rule in scope.');
        System.assertEquals(true, withAll.isReady, 'All: one failing amount keeps it out.');
    }
}