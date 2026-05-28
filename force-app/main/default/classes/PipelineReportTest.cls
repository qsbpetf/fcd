@IsTest
private class PipelineReportTest {

    private static Account makeAccount(String subsidiaryCode) {
        Account a = new Account(
            Name             = 'Test Account ' + subsidiaryCode,
            CV_Subsidiary__c = subsidiaryCode
        );
        insert a;
        return a;
    }

    private static Opportunity makeOpp(
        Account acc,
        String  stage,
        String  newOrExt,
        Date    closeDate,
        Integer probability
    ) {
        Opportunity o = new Opportunity(
            Name                = 'Test Opp ' + Math.random(),
            AccountId           = acc.Id,
            StageName           = stage,
            CloseDate           = closeDate,
            New_or_Extension__c = newOrExt,
            Probability         = probability,
            Amount              = 10000
        );
        insert o;
        return o;
    }

    @IsTest static void testFmt_nullAndZero() {
        System.assertEquals('€0', WeeklyPipelineReport.fmt(null));
        System.assertEquals('€0', WeeklyPipelineReport.fmt(0));
    }

    @IsTest static void testFmt_allRanges() {
        System.assert(WeeklyPipelineReport.fmt(750).contains('750'),     'Expected 750');
        System.assert(WeeklyPipelineReport.fmt(45000).contains('45'),    'Expected 45k');
        System.assert(WeeklyPipelineReport.fmt(1250000).contains('1.'),  'Expected 1.xM');
        System.assert(WeeklyPipelineReport.fmt(34100000).contains('34'), 'Expected 34.xM');
    }

    @IsTest static void testMonthName() {
        System.assertEquals('January',  WeeklyPipelineReport.monthName(1));
        System.assertEquals('June',     WeeklyPipelineReport.monthName(6));
        System.assertEquals('December', WeeklyPipelineReport.monthName(12));
    }

    @IsTest static void testSafeDecimal() {
        AggregateResult ar = [
            SELECT SUM(Amount) total
            FROM   Opportunity
            WHERE  Name = 'NOTEXIST99'
        ];
        System.assertEquals(0, WeeklyPipelineReport.safeDecimal(ar, 'total'));
    }

    @IsTest static void testSubsidiaryMap() {
        System.assertEquals('Finland',
            WeeklyPipelineReport.SUBSIDIARY_MAP.get('2'));
        System.assertEquals('United Kingdom',
            WeeklyPipelineReport.SUBSIDIARY_MAP.get('33'));
        System.assertEquals('Germany',
            WeeklyPipelineReport.SUBSIDIARY_MAP.get('20'));
        System.assertEquals('Denmark',
            WeeklyPipelineReport.SUBSIDIARY_MAP.get('3'));
        System.assertEquals('Sweden',
            WeeklyPipelineReport.SUBSIDIARY_MAP.get('8'));
    }

    @IsTest static void testTypeConstants() {
        System.assert(
            WeeklyPipelineReport.TYPE_NEW.contains(
                'New (New Project required in NS)'),
            'TYPE_NEW missing');
        System.assert(
            WeeklyPipelineReport.TYPE_EXTENSION.contains(
                'Extension (Use Existing Project in NS)'),
            'TYPE_EXTENSION missing first');
        System.assert(
            WeeklyPipelineReport.TYPE_EXTENSION.contains(
                'Extension (New Project required in NS)'),
            'TYPE_EXTENSION missing second');
    }

    @IsTest static void testSection1() {
        Date today   = Date.today();
        Date cyStart = Date.newInstance(today.year(), 1, 1);
        Test.startTest();
        String r = WeeklyPipelineReport.section1_TotalBookings(cyStart, today);
        Test.stopTest();
        System.assert(r.contains('BOOKINGS'), 'Missing BOOKINGS');
        System.assert(r.contains('Target'),   'Missing Target');
    }

    @IsTest static void testSection2() {
        Date    today      = Date.today();
        Date    monthStart = Date.newInstance(today.year(), today.month(), 1);
        Account acc        = makeAccount('2');
        makeOpp(acc, 'Closed Won',
            'New (New Project required in NS)', today, 100);
        makeOpp(acc, 'Closed Won',
            'Extension (Use Existing Project in NS)', today, 100);
        Test.startTest();
        String r = WeeklyPipelineReport.section2_MonthlyClosedWon(monthStart, today);
        Test.stopTest();
        System.assert(r.contains('CLOSED IN'),  'Missing CLOSED IN');
        System.assert(r.contains('New:'),        'Missing New');
        System.assert(r.contains('Extension:'),  'Missing Extension');
        System.assert(r.contains('Services:'),   'Missing Services');
        System.assert(r.contains('Licenses:'),   'Missing Licenses');
    }

    @IsTest static void testSection3() {
        Test.startTest();
        String r = WeeklyPipelineReport.section3_OpenPipeline(Date.today());
        Test.stopTest();
        System.assert(r.contains('OPEN NET PIPELINE'), 'Missing header');
        System.assert(r.contains('Early Stage'),        'Missing Early Stage');
    }

    @IsTest static void testSection4() {
        Date today   = Date.today();
        Date cyStart = Date.newInstance(today.year(), 1, 1);
        Test.startTest();
        String r = WeeklyPipelineReport.section4_PipelineGeneration(cyStart, today.addDays(-7));
        Test.stopTest();
        System.assert(r.contains('PIPELINE GENERATION'), 'Missing header');
        System.assert(r.contains('target'),               'Missing target');
    }

    @IsTest static void testSection5() {
        Date today      = Date.today();
        Date monthStart = Date.newInstance(today.year(), today.month(), 1);
        Test.startTest();
        String r = WeeklyPipelineReport.section5_KeyDeals(monthStart, today);
        Test.stopTest();
        System.assert(r.contains('KEY DEALS'), 'Missing KEY DEALS');
        System.assert(r.contains('Services'),  'Missing Services');
    }

    @IsTest static void testSection6() {
        Account fin = makeAccount('2');
        makeOpp(fin, 'Prospecting',
            'New (New Project required in NS)',
            Date.today().addDays(-10), 20);
        Test.startTest();
        String r = WeeklyPipelineReport.section6_ExpiredPipeline(Date.today());
        Test.stopTest();
        System.assert(r.contains('EXPIRED PIPELINE'), 'Missing header');
        System.assert(r.contains('Total:'),            'Missing Total');
    }

    @IsTest static void testBuildReport_allSections() {
        Account acc = makeAccount('2');
        makeOpp(acc, 'Closed Won',
            'New (New Project required in NS)', Date.today(), 100);
        Test.startTest();
        List<WeeklyPipelineReport.ReportResult> results =
            WeeklyPipelineReport.buildReport(new List<String>{ 'run' });
        Test.stopTest();
        System.assertEquals(1, results.size(), 'Expected 1 result');
        String msg = results[0].slackMessage;
        System.assert(String.isNotBlank(msg),              'Blank message');
        System.assert(msg.contains('Weekly Update'),       'Missing header');
        System.assert(msg.contains('BOOKINGS'),            'Missing S1');
        System.assert(msg.contains('CLOSED IN'),           'Missing S2');
        System.assert(msg.contains('OPEN NET PIPELINE'),   'Missing S3');
        System.assert(msg.contains('PIPELINE GENERATION'), 'Missing S4');
        System.assert(msg.contains('KEY DEALS'),           'Missing S5');
        System.assert(msg.contains('EXPIRED PIPELINE'),    'Missing S6');
    }

    @IsTest static void testBuildReport_noData() {
        Test.startTest();
        List<WeeklyPipelineReport.ReportResult> results =
            WeeklyPipelineReport.buildReport(new List<String>{ 'run' });
        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assert(String.isNotBlank(results[0].slackMessage));
    }
}