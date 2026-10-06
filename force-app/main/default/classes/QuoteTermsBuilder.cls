/**
 * Turns a QuoteTermsResolver.Resolution into rich-text HTML.
 * The same HTML is stored on the Quote (Offer_Introduction__c, Terms_And_Conditions__c) – so standard
 * Salesforce quote templates can show it – and rendered by the QuoteModularPdf Visualforce page.
 * Only tags allowed in Rich Text Area fields are used (p, b, br, ul, li, a, table).
 */
public with sharing class QuoteTermsBuilder {

    public static String introHtml(QuoteTermsResolver.Resolution r) {
        String html = '';
        for (QuoteTermsResolver.ModuleView m : r.modules) {
            if (m.placement == 'Intro') html += nz(m.body);
        }
        return html;
    }

    public static String termsHtml(QuoteTermsResolver.Resolution r, String governingAgreement,
                                   Date governingDate, String bespokeTerms) {
        Boolean german = r.isGerman();
        Map<String, String> labels = QuoteDocLabels.get(german);
        List<QuoteTermsResolver.ModuleView> sections = new List<QuoteTermsResolver.ModuleView>();
        List<QuoteTermsResolver.ModuleView> bullets = new List<QuoteTermsResolver.ModuleView>();
        List<QuoteTermsResolver.ModuleView> closings = new List<QuoteTermsResolver.ModuleView>();
        for (QuoteTermsResolver.ModuleView m : r.modules) {
            if (m.placement == 'Terms') sections.add(m);
            else if (m.placement == 'Additional') bullets.add(m);
            else if (m.placement == 'Closing') closings.add(m);
        }

        String html = '';

        // Bespoke terms (account MSA / customer specific) come first
        if (String.isNotBlank(governingAgreement) || String.isNotBlank(bespokeTerms)) {
            html += '<p><b>' + labels.get('bespokeTerms') + '</b></p>';
            if (String.isNotBlank(governingAgreement)) {
                html += '<p>' + labels.get('governedBy') + ' ' + governingAgreement.escapeHtml4()
                      + (governingDate == null ? '' : ' ' + labels.get('dated') + ' ' + QuoteDocLabels.formatDate(governingDate, german))
                      + '.</p>';
            }
            html += nz(bespokeTerms);
        }

        Boolean additionalWritten = false;
        for (QuoteTermsResolver.ModuleView s : sections) {
            if (!additionalWritten && s.sortOrder != null && s.sortOrder > QuoteTermsResolver.ADDITIONAL_LIST_POSITION) {
                html += additionalList(bullets, labels);
                additionalWritten = true;
            }
            if (String.isNotBlank(s.title)) html += '<p><b>' + s.title.escapeHtml4() + '</b></p>';
            html += nz(s.body);
        }
        if (!additionalWritten) html += additionalList(bullets, labels);

        for (QuoteTermsResolver.ModuleView c : closings) html += '<p>&nbsp;</p>' + nz(c.body);
        return html;
    }

    private static String additionalList(List<QuoteTermsResolver.ModuleView> bullets, Map<String, String> labels) {
        if (bullets.isEmpty()) return '';
        String html = '<p><b>' + labels.get('additionalTerms') + '</b></p><ul>';
        for (QuoteTermsResolver.ModuleView b : bullets) html += '<li>' + nz(b.body) + '</li>';
        return html + '</ul>';
    }

    private static String nz(String s) { return s == null ? '' : s; }
}