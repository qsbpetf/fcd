/**
 * Controller for the QuoteModularPdf Visualforce page.
 * URL parameters: id (Quote Id, required), lang (English/German, optional), format=html (browser preview).
 * Terms are built live by QuoteTermsBuilder – unless the quote's terms are locked, then the stored
 * (manually edited) Terms_And_Conditions__c is printed.
 */
public with sharing class QuotePdfController {

    // Existing org fields – adjust to your org. A path that does not exist is skipped silently.
    public static final String PAYMENT_TERMS_PATH   = 'Payment_Terms__c';
    public static final String CUSTOMER_VAT_PATH    = 'Opportunity.Account.VAT_Number__c';
    public static final String INVOICE_CONTACT_PATH = 'Opportunity.Account.Invoice_Contact__r.Name';
    public static final String LINE_END_DATE_PATH   = 'End_Date__c';
    public static final String LINE_UOM_PATH        = 'Product2.QuantityUnitOfMeasure';

    public Quote quoteRec { get; private set; }
    public QuoteTermsResolver.Resolution res { get; private set; }
    public Quote_Template_Variant__mdt variant { get; private set; }
    public Map<String, String> labels { get; private set; }
    public List<LineRow> lines { get; private set; }

    public String renderAs { get; private set; }
    public String offerTitle { get; private set; }
    public String offerSubtitle { get; private set; }
    public Boolean isBinding { get; private set; }
    public String introHtml { get; private set; }
    public String termsHtml { get; private set; }
    public String createdDateText { get; private set; }
    public String expirationDateText { get; private set; }
    public String paymentTerms { get; private set; }
    public String customerVat { get; private set; }
    public String invoiceContact { get; private set; }
    public String accountName { get; private set; }
    public String billingAddress { get; private set; }
    public String shippingAddress { get; private set; }
    public String totalListText { get; private set; }
    public String totalDiscountText { get; private set; }
    public String totalSalesText { get; private set; }
    public String logoUrl { get; private set; }
    public String footerText { get; private set; }
    public Boolean hasEndDates { get; private set; }
    public Boolean hasUnitOfMeasure { get; private set; }
    public Boolean showDiscount { get; private set; }
    public String watermarkText { get; private set; }
    public String contactName { get; private set; }
    public String entityDetails { get; private set; }
    public List<QuoteTermsResolver.ModuleView> noticeModules { get; private set; }
    public List<QuoteTermsResolver.ModuleView> promoModules { get; private set; }

    private String currencyCode;
    private Boolean german;

    public class LineRow {
        public String product { get; set; }
        public String info { get; set; }
        public String quantity { get; set; }
        public String unitOfMeasure { get; set; }
        public String discount { get; set; }
        public String unitPrice { get; set; }
        public String salesPrice { get; set; }
        public String startDate { get; set; }
        public String endDate { get; set; }
    }

    public QuotePdfController() {
        Map<String, String> params = ApexPages.currentPage().getParameters();
        Id quoteId = params.get('id');
        renderAs = params.get('format') == 'html' ? null : 'pdf';

        res = QuoteTermsResolver.resolve(quoteId, params.get('lang'));
        variant = res.variant;
        german = res.isGerman();
        labels = QuoteDocLabels.get(german);
        isBinding = res.offerType == QuoteTermsResolver.BINDING;
        offerTitle = labels.get('offer');
        offerSubtitle = isBinding ? labels.get('bindingOffer') : labels.get('nonBindingOffer');

        loadQuote(quoteId);
        loadLines(quoteId);
        introHtml = QuoteTermsBuilder.introHtml(res);
        termsHtml = (quoteRec.Terms_Locked__c && String.isNotBlank(quoteRec.Terms_And_Conditions__c))
            ? quoteRec.Terms_And_Conditions__c
            : QuoteTermsBuilder.termsHtml(res, quoteRec.Governing_Agreement__c, quoteRec.Governing_Agreement_Date__c, quoteRec.Bespoke_Terms__c);
        noticeModules = new List<QuoteTermsResolver.ModuleView>();
        promoModules = new List<QuoteTermsResolver.ModuleView>();
        for (QuoteTermsResolver.ModuleView m : res.modules) {
            if (m.placement == 'Notice') noticeModules.add(m);
            else if (m.placement == 'Promo') promoModules.add(m);
        }
        entityDetails = joinNonBlank(new List<String>{ variant.Legal_Entity_Name__c
            + (String.isBlank(variant.Business_ID__c) ? '' : ' (' + variant.Business_ID__c + ')'), oneLine(variant.Address__c) }, ', ');
        buildFooter();
        loadLogo();
    }

    // ------------------------------------------------------------------------------------ data load
    private void loadQuote(Id quoteId) {
        List<String> fields = new List<String>{
            'Id', 'Name', 'QuoteNumber', 'CreatedDate', 'ExpirationDate',
            'BillingName', 'BillingStreet', 'BillingPostalCode', 'BillingCity', 'BillingState', 'BillingCountry',
            'ShippingName', 'ShippingStreet', 'ShippingPostalCode', 'ShippingCity', 'ShippingState', 'ShippingCountry',
            'Contact.Name', 'Opportunity.Account.Name', 'CreatedBy.Name', 'CreatedBy.Email',
            'Governing_Agreement__c', 'Governing_Agreement_Date__c', 'Bespoke_Terms__c',
            'Terms_Locked__c', 'Terms_And_Conditions__c', 'Hide_Discount__c', 'Watermark_Text__c'
        };
        Boolean multiCurrency = Schema.SObjectType.Quote.fields.getMap().containsKey('currencyisocode');
        if (multiCurrency) fields.add('CurrencyIsoCode');
        for (String p : new List<String>{ PAYMENT_TERMS_PATH, CUSTOMER_VAT_PATH, INVOICE_CONTACT_PATH }) {
            if (isValidPath(Quote.SObjectType, p)) fields.add(p);
        }
        quoteRec = Database.query('SELECT ' + String.join(fields, ', ') + ' FROM Quote WHERE Id = :quoteId');

        currencyCode = multiCurrency ? (String) quoteRec.get('CurrencyIsoCode') : null;
        paymentTerms = textAt(quoteRec, PAYMENT_TERMS_PATH);
        customerVat = textAt(quoteRec, CUSTOMER_VAT_PATH);
        invoiceContact = textAt(quoteRec, INVOICE_CONTACT_PATH);
        showDiscount = !quoteRec.Hide_Discount__c;
        watermarkText = quoteRec.Watermark_Text__c;
        contactName = quoteRec.Contact == null ? '' : quoteRec.Contact.Name;
        accountName = String.isNotBlank(quoteRec.BillingName) ? quoteRec.BillingName
            : (quoteRec.Opportunity != null && quoteRec.Opportunity.Account != null ? quoteRec.Opportunity.Account.Name : '');
        createdDateText = QuoteDocLabels.formatDate(quoteRec.CreatedDate == null ? null : quoteRec.CreatedDate.date(), german);
        expirationDateText = QuoteDocLabels.formatDate(quoteRec.ExpirationDate, german);
        billingAddress = joinNonBlank(new List<String>{ quoteRec.BillingStreet,
            joinNonBlank(new List<String>{ quoteRec.BillingPostalCode, quoteRec.BillingCity }, ' '),
            quoteRec.BillingState, quoteRec.BillingCountry }, ', ');
        shippingAddress = joinNonBlank(new List<String>{ quoteRec.ShippingName, quoteRec.ShippingStreet,
            joinNonBlank(new List<String>{ quoteRec.ShippingPostalCode, quoteRec.ShippingCity }, ' '),
            quoteRec.ShippingState, quoteRec.ShippingCountry }, ', ');
    }

    private void loadLines(Id quoteId) {
        List<String> fields = new List<String>{
            'Id', 'Product2.Name', 'Description', 'Quantity', 'ListPrice', 'UnitPrice', 'TotalPrice', 'ServiceDate', 'Discount'
        };
        hasEndDates = isValidPath(QuoteLineItem.SObjectType, LINE_END_DATE_PATH);
        if (hasEndDates) fields.add(LINE_END_DATE_PATH);
        Boolean uomAvailable = isValidPath(QuoteLineItem.SObjectType, LINE_UOM_PATH);
        if (uomAvailable) fields.add(LINE_UOM_PATH);
        hasUnitOfMeasure = false;

        lines = new List<LineRow>();
        Decimal totalList = 0, totalSales = 0;
        for (QuoteLineItem li : Database.query('SELECT ' + String.join(fields, ', ')
                + ' FROM QuoteLineItem WHERE QuoteId = :quoteId ORDER BY SortOrder, CreatedDate')) {
            LineRow row = new LineRow();
            row.product = li.Product2 == null ? '' : li.Product2.Name;
            row.info = li.Description;
            row.quantity = li.Quantity == null ? '' : li.Quantity.stripTrailingZeros().toPlainString();
            row.unitOfMeasure = uomAvailable ? textAt(li, LINE_UOM_PATH) : '';
            if (String.isNotBlank(row.unitOfMeasure)) hasUnitOfMeasure = true;
            row.discount = (li.Discount == null || li.Discount == 0) ? '' : li.Discount.stripTrailingZeros().toPlainString() + ' %';
            row.unitPrice = fmtNumber(li.UnitPrice);
            row.salesPrice = fmtNumber(li.TotalPrice);
            row.startDate = QuoteDocLabels.formatDate(li.ServiceDate, german);
            row.endDate = hasEndDates ? QuoteDocLabels.formatDate((Date) li.get(LINE_END_DATE_PATH), german) : '';
            lines.add(row);

            Decimal qty = li.Quantity == null ? 0 : li.Quantity;
            Decimal listUnit = li.ListPrice != null ? li.ListPrice : (li.UnitPrice == null ? 0 : li.UnitPrice);
            totalList += listUnit * qty;
            totalSales += li.TotalPrice == null ? 0 : li.TotalPrice;
        }
        totalListText = fmtMoney(totalList);
        totalDiscountText = fmtMoney(totalList - totalSales);
        totalSalesText = fmtMoney(totalSales);
    }

    private void buildFooter() {
        List<String> parts = new List<String>{ variant.Legal_Entity_Name__c, oneLine(variant.Address__c) };
        if (String.isNotBlank(variant.Business_ID__c)) parts.add(labels.get('businessId') + ' ' + variant.Business_ID__c);
        if (String.isNotBlank(variant.Footer_Contact__c)) parts.add(variant.Footer_Contact__c);
        if (variant.Show_Bank_Details__c) {
            if (String.isNotBlank(variant.Managing_Director__c)) parts.add(labels.get('managingDirector') + ': ' + variant.Managing_Director__c);
            if (String.isNotBlank(variant.Commercial_Register__c)) parts.add(variant.Commercial_Register__c);
            if (String.isNotBlank(variant.VAT_ID__c)) parts.add(labels.get('vatId') + ' ' + variant.VAT_ID__c);
            if (String.isNotBlank(variant.Bank_Details__c)) parts.add(oneLine(variant.Bank_Details__c));
        }
        footerText = joinNonBlank(parts, '  |  ');
    }

    private void loadLogo() {
        if (String.isBlank(variant.Logo_Static_Resource__c)) return;
        String resName = variant.Logo_Static_Resource__c;
        List<StaticResource> srs = [SELECT Name, SystemModstamp FROM StaticResource WHERE Name = :resName LIMIT 1];
        if (!srs.isEmpty()) logoUrl = '/resource/' + srs[0].SystemModstamp.getTime() + '/' + srs[0].Name;
    }

    // ---------------------------------------------------------------------------------- formatting
    private String fmtMoney(Decimal d) {
        return (currencyCode == null ? '' : currencyCode + ' ') + fmtNumber(d);
    }

    private String fmtNumber(Decimal d) {
        if (d == null) return '';
        Decimal v = d.setScale(2, System.RoundingMode.HALF_UP);
        String plain = v.abs().toPlainString();
        String intPart = plain.substringBefore('.');
        String decPart = plain.contains('.') ? plain.substringAfter('.') : '00';
        String thousands = german ? '.' : ',';
        String grouped = '';
        while (intPart.length() > 3) {
            grouped = thousands + intPart.right(3) + grouped;
            intPart = intPart.left(intPart.length() - 3);
        }
        return (v < 0 ? '-' : '') + intPart + grouped + (german ? ',' : '.') + decPart;
    }

    private static String oneLine(String s) {
        return s == null ? null : s.replace('\r', '').replace('\n', ', ');
    }

    private static String joinNonBlank(List<String> values, String sep) {
        List<String> out = new List<String>();
        for (String v : values) if (String.isNotBlank(v)) out.add(v.trim());
        return String.join(out, sep);
    }

    // ------------------------------------------------------------------------- dynamic field paths
    @TestVisible
    private static Boolean isValidPath(Schema.SObjectType rootType, String path) {
        if (String.isBlank(path)) return false;
        Schema.SObjectType current = rootType;
        List<String> parts = path.split('\\.');
        for (Integer i = 0; i < parts.size(); i++) {
            Map<String, Schema.SObjectField> fieldMap = current.getDescribe().fields.getMap();
            if (i == parts.size() - 1) return fieldMap.containsKey(parts[i].toLowerCase());
            Schema.SObjectType next = null;
            for (Schema.SObjectField f : fieldMap.values()) {
                Schema.DescribeFieldResult dfr = f.getDescribe();
                if (dfr.getRelationshipName() != null && dfr.getRelationshipName().equalsIgnoreCase(parts[i])
                        && !dfr.getReferenceTo().isEmpty()) {
                    next = dfr.getReferenceTo()[0];
                    break;
                }
            }
            if (next == null) return false;
            current = next;
        }
        return false;
    }

    private String textAt(SObject rec, String path) {
        if (!isValidPath(rec.getSObjectType(), path)) return '';
        List<String> parts = path.split('\\.');
        SObject cur = rec;
        for (Integer i = 0; i < parts.size() - 1; i++) {
            if (cur == null) return '';
            cur = cur.getSObject(parts[i]);
        }
        if (cur == null) return '';
        Object v = cur.get(parts[parts.size() - 1]);
        if (v == null) return '';
        if (v instanceof Date) return QuoteDocLabels.formatDate((Date) v, german);
        return String.valueOf(v);
    }
}