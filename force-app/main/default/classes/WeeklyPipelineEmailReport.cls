/**
 * WeeklyPipelineEmailReport
 * ─────────────────────────────────────────────────────────────────────
 * HTML email version of the weekly pipeline report.
 * Use this Apex Action in the email Flow.
 * ─────────────────────────────────────────────────────────────────────
 */
public with sharing class WeeklyPipelineEmailReport {

    public class ReportResult {
        @InvocableVariable(
            label       = 'Email Message'
            description = 'HTML formatted email body. Pass to Send Email element.'
            required    = false
        )
        public String emailMessage;
    }

    @InvocableMethod(
        label       = 'Build Weekly Pipeline Email Message'
        description = 'Returns HTML formatted weekly report with styling and clickable Opportunity links'
    )
    public static List<ReportResult> buildEmailReport(List<String> dummy) {
        ReportResult result  = new ReportResult();
        result.emailMessage  = buildEmailMessage();
        return new List<ReportResult>{ result };
    }

    // ── TARGETS ─────────────────────────────────────────────────────
    private static Decimal TARGET_BOOKINGS_CY      = 34100000;
    private static Decimal TARGET_SERVICES_CY      = 43200000;
    private static Decimal TARGET_LICENSES_CY      =  6150000;
    private static Decimal TARGET_SERVICES_MONTHLY =  5500000;
    private static Decimal TARGET_LICENSES_MONTHLY =  2000000;

    // ── STAGE VALUES ─────────────────────────────────────────────────
    private static Set<String> STAGE_CLOSED = new Set<String>{
        'Closed Won',
        'Closed Won - Awaiting Approval',
        'Order'
    };

    // ── NEW OR EXTENSION VALUES ──────────────────────────────────────
    private static Set<String> TYPE_NEW = new Set<String>{
        'New (New Project required in NS)'
    };
    private static Set<String> TYPE_EXTENSION = new Set<String>{
        'Extension (Use Existing Project in NS)',
        'Extension (New Project required in NS)'
    };

    // ── SUBSIDIARY MAP ───────────────────────────────────────────────
    private static Map<String,String> SUBSIDIARY_MAP = new Map<String,String>{
        '2'  => 'Finland',
        '3'  => 'Denmark',
        '5'  => 'Netherlands',
        '7'  => 'Norway',
        '8'  => 'Sweden',
        '9'  => 'Poland',
        '10' => 'Switzerland',
        '12' => 'United States',
        '20' => 'Germany',
        '33' => 'United Kingdom'
    };

    // ───────────────────────────────────────────────────────────────
    // MAIN BUILDER
    // ───────────────────────────────────────────────────────────────
    static String buildEmailMessage() {
        Date    today      = Date.today();
        Date    cyStart    = Date.newInstance(today.year(), 1, 1);
        Date    monthStart = Date.newInstance(today.year(), today.month(), 1);
        Date    weekStart  = today.addDays(-7);
        Integer weekNum    = cyStart.daysBetween(today) / 7 + 1;

        String msg = '<html><body style="font-family:Arial,sans-serif;font-size:14px;color:#222;max-width:700px;">';
        msg += emailHeader(weekNum, today.year());
        msg += section1(cyStart, today);
        msg += section2(monthStart, today);
        msg += section3(today);
        msg += section4(cyStart, weekStart);
        msg += section5(monthStart, today);
        msg += section6(today);
        msg += '</body></html>';
        return msg;
    }

    // ───────────────────────────────────────────────────────────────
    // HEADER
    // ───────────────────────────────────────────────────────────────
    static String emailHeader(Integer weekNum, Integer year) {
        return '<h2 style="color:#1a73e8;border-bottom:2px solid #1a73e8;padding-bottom:8px;">'
             + '&#128202; Salesforce Weekly Update &#8211; Week '
             + weekNum + ' (' + year + ')'
             + '</h2>';
    }

    // ───────────────────────────────────────────────────────────────
    // SECTION 1 — Total Bookings (Calendar Year)
    // ───────────────────────────────────────────────────────────────
    static String section1(Date cyStart, Date today) {
        AggregateResult[] res = [
            SELECT SUM(Net_Revenue__c) total
            FROM   Opportunity
            WHERE  StageName IN :STAGE_CLOSED
            AND    CloseDate >= :cyStart
            AND    CloseDate <= :today
        ];
        Decimal total = safeDecimal(res[0], 'total');
        return '<h3 style="color:#333;margin-bottom:4px;">BOOKINGS &#8211; Calendar Year</h3>'
             + '<ul style="margin-top:4px;">'
             + '<li>Total: <strong>' + fmt(total) + '</strong>'
             + ' vs ' + fmt(TARGET_BOOKINGS_CY) + ' Target</li>'
             + '</ul>';
    }

    // ───────────────────────────────────────────────────────────────
    // SECTION 2 — Monthly Closed Won Breakdown
    // ───────────────────────────────────────────────────────────────
    static String section2(Date monthStart, Date today) {
        AggregateResult[] newRes = [
            SELECT SUM(Net_Revenue__c) total
            FROM   Opportunity
            WHERE  StageName IN :STAGE_CLOSED
            AND    CloseDate >= :monthStart
            AND    CloseDate <= :today
            AND    New_or_Extension__c IN :TYPE_NEW
        ];
        AggregateResult[] extRes = [
            SELECT SUM(Net_Revenue__c) total
            FROM   Opportunity
            WHERE  StageName IN :STAGE_CLOSED
            AND    CloseDate >= :monthStart
            AND    CloseDate <= :today
            AND    New_or_Extension__c IN :TYPE_EXTENSION
        ];
        AggregateResult[] svcRes = [
            SELECT SUM(Total_Amount_Services_Final__c) total
            FROM   Opportunity
            WHERE  StageName IN :STAGE_CLOSED
            AND    CloseDate >= :monthStart
            AND    CloseDate <= :today
        ];
        AggregateResult[] licRes = [
            SELECT SUM(Total_Margin_Licences_Final__c) total
            FROM   Opportunity
            WHERE  StageName IN :STAGE_CLOSED
            AND    CloseDate >= :monthStart
            AND    CloseDate <= :today
        ];
        String month = monthName(today.month());
        return '<h3 style="color:#333;margin-bottom:4px;">CLOSED IN ' + month.toUpperCase() + '</h3>'
             + '<ul style="margin-top:4px;">'
             + '<li>New: <strong>'       + fmt(safeDecimal(newRes[0], 'total')) + '</strong></li>'
             + '<li>Extension: <strong>' + fmt(safeDecimal(extRes[0], 'total')) + '</strong></li>'
             + '<li><em>Services:</em> <strong>' + fmt(safeDecimal(svcRes[0], 'total')) + '</strong>'
             + ' vs ' + fmt(TARGET_SERVICES_MONTHLY) + ' target</li>'
             + '<li><em>Licenses:</em> <strong>' + fmt(safeDecimal(licRes[0], 'total')) + '</strong>'
             + ' vs ' + fmt(TARGET_LICENSES_MONTHLY) + ' target</li>'
             + '</ul>';
    }

    // ───────────────────────────────────────────────────────────────
    // SECTION 3 — Open Pipeline
    // Early stage = Probability < 50%
    // SOQL does not support CASE/WHEN in SUM() — separate queries used
    // ───────────────────────────────────────────────────────────────
    static String section3(Date today) {
        AggregateResult[] svcTotalRes = [
            SELECT SUM(Total_Amount_Services_Final__c) total
            FROM   Opportunity
            WHERE  IsClosed = false
            AND    CloseDate >= :today
            AND    Total_Amount_Services_Final__c > 0
        ];
        AggregateResult[] svcEarlyRes = [
            SELECT SUM(Total_Amount_Services_Final__c) total
            FROM   Opportunity
            WHERE  IsClosed = false
            AND    CloseDate >= :today
            AND    Total_Amount_Services_Final__c > 0
            AND    Probability < 50
        ];
        AggregateResult[] licTotalRes = [
            SELECT SUM(Total_Margin_Licences_Final__c) total
            FROM   Opportunity
            WHERE  IsClosed = false
            AND    CloseDate >= :today
            AND    Total_Margin_Licences_Final__c > 0
        ];
        AggregateResult[] licEarlyRes = [
            SELECT SUM(Total_Margin_Licences_Final__c) total
            FROM   Opportunity
            WHERE  IsClosed = false
            AND    CloseDate >= :today
            AND    Total_Margin_Licences_Final__c > 0
            AND    Probability < 50
        ];
        Decimal svcT = safeDecimal(svcTotalRes[0], 'total');
        Decimal svcE = safeDecimal(svcEarlyRes[0], 'total');
        Decimal licT = safeDecimal(licTotalRes[0], 'total');
        Decimal licE = safeDecimal(licEarlyRes[0], 'total');
        Integer svcPct = svcT > 0 ? Integer.valueOf(svcE / svcT * 100) : 0;
        Integer licPct = licT > 0 ? Integer.valueOf(licE / licT * 100) : 0;
        return '<h3 style="color:#333;margin-bottom:4px;">OPEN NET PIPELINE</h3>'
             + '<ul style="margin-top:4px;">'
             + '<li>Services: <strong>' + fmt(svcT) + '</strong>'
             + ' &nbsp;<em>Early Stage (' + svcPct + '%): ' + fmt(svcE) + '</em></li>'
             + '<li>Licenses: <strong>' + fmt(licT) + '</strong>'
             + ' &nbsp;<em>Early Stage (' + licPct + '%): ' + fmt(licE) + '</em></li>'
             + '</ul>';
    }

    // ───────────────────────────────────────────────────────────────
    // SECTION 4 — Pipeline Generation (CY + last week highlights)
    // ───────────────────────────────────────────────────────────────
    static String section4(Date cyStart, Date weekStart) {
        DateTime cyStartDT   = DateTime.newInstance(cyStart,   Time.newInstance(0,0,0,0));
        DateTime weekStartDT = DateTime.newInstance(weekStart, Time.newInstance(0,0,0,0));
        AggregateResult[] svcCY = [
            SELECT SUM(Total_Amount_Services_Final__c) total
            FROM   Opportunity
            WHERE  CreatedDate >= :cyStartDT
            AND    Total_Amount_Services_Final__c > 0
        ];
        AggregateResult[] licCY = [
            SELECT SUM(Total_Margin_Licences_Final__c) total
            FROM   Opportunity
            WHERE  CreatedDate >= :cyStartDT
            AND    Total_Margin_Licences_Final__c > 0
        ];
        List<Opportunity> svcWeek = [
            SELECT Id, Name, Total_Amount_Services_Final__c
            FROM   Opportunity
            WHERE  CreatedDate >= :weekStartDT
            AND    Total_Amount_Services_Final__c > 0
            ORDER BY Total_Amount_Services_Final__c DESC NULLS LAST
            LIMIT  3
        ];
        List<Opportunity> licWeek = [
            SELECT Id, Name, Total_Margin_Licences_Final__c
            FROM   Opportunity
            WHERE  CreatedDate >= :weekStartDT
            AND    Total_Margin_Licences_Final__c > 0
            ORDER BY Total_Margin_Licences_Final__c DESC NULLS LAST
            LIMIT  3
        ];
        return '<h3 style="color:#333;margin-bottom:4px;">PIPELINE GENERATION &#8211; Calendar Year</h3>'
             + '<ul style="margin-top:4px;">'
             + '<li>Services: <strong>' + fmt(safeDecimal(svcCY[0], 'total')) + '</strong>'
             + ' (' + fmt(TARGET_SERVICES_CY) + ' target)</li>'
             + '<li>Licenses: <strong>' + fmt(safeDecimal(licCY[0], 'total')) + '</strong>'
             + ' (' + fmt(TARGET_LICENSES_CY) + ' target)</li>'
             + '</ul>'
             + '<p style="margin-bottom:4px;"><strong>Highlights last week &#8211; Services:</strong></p>'
             + '<ul style="margin-top:4px;">' + oppLinesSvc(svcWeek) + '</ul>'
             + '<p style="margin-bottom:4px;"><strong>Highlights last week &#8211; Licenses:</strong></p>'
             + '<ul style="margin-top:4px;">' + oppLinesLic(licWeek) + '</ul>';
    }

    // ───────────────────────────────────────────────────────────────
    // SECTION 5 — Key Deals Closed Won (current month)
    // ───────────────────────────────────────────────────────────────
    static String section5(Date monthStart, Date today) {
        List<Opportunity> svcTop3 = [
            SELECT Id, Name, Total_Amount_Services_Final__c
            FROM   Opportunity
            WHERE  StageName IN :STAGE_CLOSED
            AND    CloseDate >= :monthStart
            AND    CloseDate <= :today
            AND    Total_Amount_Services_Final__c > 0
            ORDER BY Total_Amount_Services_Final__c DESC NULLS LAST
            LIMIT  3
        ];
        List<Opportunity> licTop3 = [
            SELECT Id, Name, Total_Margin_Licences_Final__c
            FROM   Opportunity
            WHERE  StageName IN :STAGE_CLOSED
            AND    CloseDate >= :monthStart
            AND    CloseDate <= :today
            AND    Total_Margin_Licences_Final__c > 0
            ORDER BY Total_Margin_Licences_Final__c DESC NULLS LAST
            LIMIT  3
        ];
        String month = monthName(today.month());
        return '<h3 style="color:#333;margin-bottom:4px;">KEY DEALS CLOSED WON &#8211; ' + month.toUpperCase() + '</h3>'
             + '<p style="margin-bottom:4px;"><strong>Services:</strong></p>'
             + '<ul style="margin-top:4px;">' + oppLinesSvc(svcTop3) + '</ul>'
             + '<p style="margin-bottom:4px;"><strong>Licenses:</strong></p>'
             + '<ul style="margin-top:4px;">' + oppLinesLic(licTop3) + '</ul>';
    }

    // ───────────────────────────────────────────────────────────────
    // SECTION 6 — Expired Pipeline
    // ───────────────────────────────────────────────────────────────
    static String section6(Date today) {
        AggregateResult[] totalRes = [
            SELECT SUM(Net_Revenue__c) total
            FROM   Opportunity
            WHERE  IsClosed = false
            AND    CloseDate < :today
        ];
        AggregateResult[] bySubsidiary = [
            SELECT Account.CV_Subsidiary__c subsidiary,
                   SUM(Net_Revenue__c)       total
            FROM   Opportunity
            WHERE  IsClosed = false
            AND    CloseDate < :today
            GROUP  BY Account.CV_Subsidiary__c
            ORDER  BY SUM(Net_Revenue__c) DESC NULLS LAST
            LIMIT  3
        ];
        String countryLines = '';
        Integer rank = 1;
        for (AggregateResult ar : bySubsidiary) {
            String code    = ar.get('subsidiary') != null
                           ? String.valueOf(ar.get('subsidiary')) : '';
            String country = SUBSIDIARY_MAP.containsKey(code)
                           ? SUBSIDIARY_MAP.get(code) : 'Other';
            countryLines  += '<li>' + rank + '. ' + country
                           + ' &#8211; ' + fmt(safeDecimal(ar, 'total')) + '</li>\n';
            rank++;
        }
        return '<h3 style="color:#333;margin-bottom:4px;">EXPIRED PIPELINE</h3>'
             + '<ul style="margin-top:4px;">'
             + '<li>Total: <strong>' + fmt(safeDecimal(totalRes[0], 'total')) + '</strong></li>'
             + '</ul>'
             + '<p style="margin-bottom:4px;"><strong>Countries with highest expired pipeline:</strong></p>'
             + '<ul style="margin-top:4px;">' + countryLines + '</ul>';
    }

    // ───────────────────────────────────────────────────────────────
    // HELPERS — Opportunity lines with clickable HTML links
    // ───────────────────────────────────────────────────────────────
    static String oppLinesSvc(List<Opportunity> opps) {
        if (opps.isEmpty()) return '<li><em>No records found</em></li>';
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String out = '';
        for (Opportunity o : opps) {
            Decimal rev = o.Total_Amount_Services_Final__c != null
                        ? o.Total_Amount_Services_Final__c : 0;
            out += '<li>'
                 + '<a href="' + baseUrl + '/' + o.Id + '" style="color:#1a73e8;">'
                 + o.Name + '</a>'
                 + ' | <strong>' + fmt(rev) + '</strong>'
                 + '</li>\n';
        }
        return out;
    }

    static String oppLinesLic(List<Opportunity> opps) {
        if (opps.isEmpty()) return '<li><em>No records found</em></li>';
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String out = '';
        for (Opportunity o : opps) {
            Decimal rev = o.Total_Margin_Licences_Final__c != null
                        ? o.Total_Margin_Licences_Final__c : 0;
            out += '<li>'
                 + '<a href="' + baseUrl + '/' + o.Id + '" style="color:#1a73e8;">'
                 + o.Name + '</a>'
                 + ' | <strong>' + fmt(rev) + '</strong>'
                 + '</li>\n';
        }
        return out;
    }

    // ───────────────────────────────────────────────────────────────
    // HELPERS — Formatters
    // ───────────────────────────────────────────────────────────────
    static String fmt(Decimal val) {
        if (val == null || val == 0) return '€0';
        if (val >= 1000000) return '€' + (val / 1000000).setScale(1) + 'M';
        if (val >= 1000)    return '€' + (val / 1000).setScale(0) + 'k';
        return '€' + val.setScale(0);
    }

    static Decimal safeDecimal(AggregateResult ar, String field) {
        Object val = ar.get(field);
        return val != null ? (Decimal) val : 0;
    }

    static String monthName(Integer m) {
        List<String> names = new List<String>{
            'January','February','March','April','May','June',
            'July','August','September','October','November','December'
        };
        return names[m - 1];
    }
}