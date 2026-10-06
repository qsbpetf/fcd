/**
 * Decides which Terms & Conditions a Quote gets – driven by the PRODUCTS on the quote.
 *
 *  Quote line -> Product2.Quote_Terms_Group__c (or Product2.Family via Quote_Product_Family_Map__mdt)
 *             -> terms groups on the quote (e.g. Atlassian_License + Managed_Services)
 *             -> every Quote_Terms_Module__mdt whose condition matches is included, each clause once.
 *
 * Variant (Module B), offer type (Module A) and language narrow the choice further.
 * When several records share a Module_Code__c, only the best one is printed:
 * same language beats English fallback, a variant-specific record beats an "ALL" record.
 * Two records with the same code and different conditions therefore act as an OR.
 *
 * CMDT is read with SOQL (getAll() truncates Long Text Area to 255 chars). CMDT SOQL does not count
 * against governor limits; config is cached per transaction, so resolveAll() is bulk-safe.
 */
public with sharing class QuoteTermsResolver {

    public static final String DEFAULT_VARIANT  = 'Global';
    public static final String DEFAULT_LANGUAGE = 'English';
    public static final String BINDING          = 'Binding';
    public static final String NON_BINDING      = 'Non-binding';
    public static final Integer ADDITIONAL_LIST_POSITION = 500;

    // ------------------------------------------------------------------------------------- DTOs
    public class Resolution {
        @AuraEnabled public Id quoteId { get; set; }
        @AuraEnabled public String variantKey { get; set; }
        @AuraEnabled public String variantLabel { get; set; }
        @AuraEnabled public String issuingEntity { get; set; }
        @AuraEnabled public String language { get; set; }
        @AuraEnabled public String offerType { get; set; }
        @AuraEnabled public String offerTypeReason { get; set; }
        @AuraEnabled public List<String> categories { get; set; }
        @AuraEnabled public List<String> groups { get; set; }
        @AuraEnabled public List<ProductMapping> products { get; set; }
        @AuraEnabled public List<ModuleView> modules { get; set; }
        @AuraEnabled public List<String> warnings { get; set; }
        @AuraEnabled public Integer lineCount { get; set; }
        @AuraEnabled public Boolean termsLocked { get; set; }
        public Quote_Template_Variant__mdt variant { get; set; }

        public Resolution() {
            categories = new List<String>();
            groups = new List<String>();
            products = new List<ProductMapping>();
            modules = new List<ModuleView>();
            warnings = new List<String>();
            lineCount = 0;
            termsLocked = false;
        }
        public Boolean isGerman() { return language == 'German'; }
    }

    public class ProductMapping {
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String groupKey { get; set; }
        @AuraEnabled public String groupLabel { get; set; }
        @AuraEnabled public String source { get; set; }
    }

    public class ModuleView implements Comparable {
        @AuraEnabled public String code { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String body { get; set; }
        @AuraEnabled public String placement { get; set; }
        @AuraEnabled public String language { get; set; }
        @AuraEnabled public Decimal sortOrder { get; set; }
        @AuraEnabled public String appliesBecause { get; set; }
        @AuraEnabled public Boolean isFallback { get; set; }

        public Integer compareTo(Object other) {
            Decimal a = sortOrder == null ? 0 : sortOrder;
            ModuleView o = (ModuleView) other;
            Decimal b = o.sortOrder == null ? 0 : o.sortOrder;
            if (a == b) return code == null ? 0 : code.compareTo(o.code);
            return a > b ? 1 : -1;
        }
    }

    // ------------------------------------------------------------------------------ config cache
    private static Map<String, Quote_Template_Variant__mdt> variants;
    private static Map<String, Quote_Terms_Group__mdt> termGroups;      // key: lower-case DeveloperName
    private static Map<String, String> familyToGroup;                   // key: lower-case family
    private static List<Quote_Terms_Module__mdt> moduleRecords;

    private static void loadConfig() {
        if (moduleRecords != null) return;
        variants = new Map<String, Quote_Template_Variant__mdt>();
        for (Quote_Template_Variant__mdt v : [
            SELECT DeveloperName, MasterLabel, Legal_Entity_Name__c, Address__c, Business_ID__c, VAT_ID__c,
                   Commercial_Register__c, Managing_Director__c, Bank_Details__c, Footer_Contact__c,
                   Show_Bank_Details__c, Default_Language__c, Offer_Type_Policy__c, Logo_Static_Resource__c
            FROM Quote_Template_Variant__mdt
        ]) variants.put(v.DeveloperName.toLowerCase(), v);

        termGroups = new Map<String, Quote_Terms_Group__mdt>();
        for (Quote_Terms_Group__mdt g : [SELECT DeveloperName, MasterLabel, Category__c, Non_Binding__c FROM Quote_Terms_Group__mdt]) {
            termGroups.put(g.DeveloperName.toLowerCase(), g);
        }
        familyToGroup = new Map<String, String>();
        for (Quote_Product_Family_Map__mdt m : [SELECT Product_Family__c, Terms_Group__c FROM Quote_Product_Family_Map__mdt]) {
            if (String.isNotBlank(m.Product_Family__c)) familyToGroup.put(m.Product_Family__c.trim().toLowerCase(), m.Terms_Group__c);
        }
        moduleRecords = [
            SELECT DeveloperName, Module_Code__c, Language__c, Section_Title__c, Body__c, Placement__c, Region_Variants__c,
                   Offer_Type__c, Applies_When__c, Condition_Value__c, Exclude_Groups__c, Sort_Order__c
            FROM Quote_Terms_Module__mdt WHERE Active__c = true
        ];
    }

    // ---------------------------------------------------------------------------------- entry
    public static Resolution resolve(Id quoteId, String languageOverride) {
        Resolution r = resolveAll(new Set<Id>{ quoteId }, languageOverride).get(quoteId);
        if (r == null) throw new QuoteTermsException('Quote not found or not accessible: ' + quoteId);
        return r;
    }

    public static Map<Id, Resolution> resolveAll(Set<Id> quoteIds, String languageOverride) {
        loadConfig();
        Map<Id, Resolution> out = new Map<Id, Resolution>();
        if (quoteIds == null || quoteIds.isEmpty()) return out;
        for (Quote q : [
            SELECT Id, Template_Variant__c, Offer_Type__c, Quote_Language__c, ExpirationDate, Terms_Locked__c,
                   (SELECT Id, Product2.Name, Product2.Family, Product2.Quote_Terms_Group__c
                    FROM QuoteLineItems ORDER BY SortOrder)
            FROM Quote WHERE Id IN :quoteIds
        ]) {
            out.put(q.Id, resolveOne(q, languageOverride));
        }
        return out;
    }

    // ---------------------------------------------------------------------------------- core
    private static Resolution resolveOne(Quote q, String languageOverride) {
        Resolution r = new Resolution();
        r.quoteId = q.Id;
        r.termsLocked = q.Terms_Locked__c;

        // 1) Variant
        r.variantKey = String.isBlank(q.Template_Variant__c) ? DEFAULT_VARIANT : q.Template_Variant__c;
        if (String.isBlank(q.Template_Variant__c)) r.warnings.add('Template Variant is empty – ' + DEFAULT_VARIANT + ' is used.');
        r.variant = variants.get(r.variantKey.toLowerCase());
        if (r.variant == null) throw new QuoteTermsException('No Quote Template Variant record named ' + r.variantKey + '.');
        r.variantLabel = r.variant.MasterLabel;
        r.issuingEntity = r.variant.Legal_Entity_Name__c;

        // 2) Products -> terms groups -> categories
        Set<String> groupsLower = new Set<String>();
        Set<String> categories = new Set<String>();
        List<String> nonBindingGroups = new List<String>();
        Set<String> seenProducts = new Set<String>();
        Boolean hasUnmapped = false;

        for (QuoteLineItem li : q.QuoteLineItems) {
            ProductMapping pm = new ProductMapping();
            pm.productName = li.Product2 == null ? '(no product)' : li.Product2.Name;
            String groupKey = li.Product2 == null ? null : li.Product2.Quote_Terms_Group__c;
            pm.source = 'Product';
            if (String.isBlank(groupKey) && li.Product2 != null && String.isNotBlank(li.Product2.Family)) {
                groupKey = familyToGroup.get(li.Product2.Family.trim().toLowerCase());
                pm.source = 'Product family "' + li.Product2.Family + '"';
            }
            Quote_Terms_Group__mdt g = String.isBlank(groupKey) ? null : termGroups.get(groupKey.toLowerCase());
            if (g == null) {
                hasUnmapped = true;
                pm.groupKey = null;
                pm.groupLabel = 'Not mapped';
                pm.source = 'Set Quote Terms Group on the product';
            } else {
                pm.groupKey = g.DeveloperName;
                pm.groupLabel = g.MasterLabel;
                if (!groupsLower.contains(g.DeveloperName.toLowerCase())) {
                    r.groups.add(g.MasterLabel);
                    if (g.Non_Binding__c) nonBindingGroups.add(g.MasterLabel);
                }
                groupsLower.add(g.DeveloperName.toLowerCase());
                if (String.isNotBlank(g.Category__c)) categories.add(g.Category__c);
            }
            String key = pm.productName + '|' + pm.groupKey;
            if (!seenProducts.contains(key)) { r.products.add(pm); seenProducts.add(key); }
        }
        r.lineCount = q.QuoteLineItems.size();
        r.categories.addAll(categories);
        r.categories.sort();
        if (hasUnmapped) r.warnings.add('Some products have no Quote Terms Group – their terms are missing and the offer is treated as non-binding.');
        if (r.lineCount == 0) r.warnings.add('The Quote has no line items yet – only general terms are included.');
        if (q.ExpirationDate == null) r.warnings.add('Expiration Date is empty – it should always be set, especially for licences.');

        // 3) Offer type (Module A1 / A2)
        String policy = r.variant.Offer_Type_Policy__c;
        if (policy == 'Always Binding' || policy == 'Always Non-binding') {
            r.offerType = policy == 'Always Binding' ? BINDING : NON_BINDING;
            r.offerTypeReason = r.variantLabel + ' always uses a ' + r.offerType.toLowerCase() + ' offer.';
            if (String.isNotBlank(q.Offer_Type__c) && q.Offer_Type__c != r.offerType) {
                r.warnings.add('Offer Type on the Quote (' + q.Offer_Type__c + ') is overridden by the ' + r.variantLabel + ' policy.');
            }
        } else if (String.isNotBlank(q.Offer_Type__c)) {
            r.offerType = q.Offer_Type__c;
            r.offerTypeReason = 'Set manually on the Quote.';
        } else if (r.lineCount == 0) {
            r.offerType = NON_BINDING;
            r.offerTypeReason = 'No products yet, so non-binding by default.';
        } else if (!nonBindingGroups.isEmpty() || hasUnmapped) {
            r.offerType = NON_BINDING;
            r.offerTypeReason = nonBindingGroups.isEmpty()
                ? 'Unmapped products on the quote, so non-binding.'
                : 'Contains ' + String.join(nonBindingGroups, ' and ') + ', so a non-binding offer (Module A2).';
        } else {
            r.offerType = BINDING;
            r.offerTypeReason = 'No consulting or managed services on the quote, so a binding quote (Module A1).';
        }

        // 4) Language
        if (String.isNotBlank(languageOverride)) r.language = languageOverride;
        else if (String.isNotBlank(q.Quote_Language__c)) r.language = q.Quote_Language__c;
        else if (String.isNotBlank(r.variant.Default_Language__c)) r.language = r.variant.Default_Language__c;
        else r.language = DEFAULT_LANGUAGE;

        // 5) Modules – best record per Module_Code__c
        Map<String, Quote_Terms_Module__mdt> best = new Map<String, Quote_Terms_Module__mdt>();
        Map<String, Integer> bestScore = new Map<String, Integer>();
        Set<String> categoriesLower = lower(categories);
        String variantLower = r.variantKey.toLowerCase();

        for (Quote_Terms_Module__mdt m : moduleRecords) {
            String placement = String.isBlank(m.Placement__c) ? 'Terms' : m.Placement__c;
            Boolean langMatch = m.Language__c == r.language;
            // Legal clauses and notices fall back to English so nothing is silently dropped;
            // greetings, closings and promotion boxes never do.
            Boolean fallbackOk = (placement == 'Terms' || placement == 'Additional' || placement == 'Notice')
                && m.Language__c == DEFAULT_LANGUAGE;
            if (!langMatch && !fallbackOk) continue;

            Boolean allVariants = isAll(m.Region_Variants__c);
            if (!allVariants && !splitLower(m.Region_Variants__c).contains(variantLower)) continue;
            if (String.isNotBlank(m.Offer_Type__c) && m.Offer_Type__c != 'Any' && m.Offer_Type__c != r.offerType) continue;
            if (!conditionMatches(m, groupsLower, categoriesLower)) continue;
            if (intersects(splitLower(m.Exclude_Groups__c), groupsLower)) continue;

            Integer score = (langMatch ? 10 : 0) + (allVariants ? 0 : 1);
            String code = String.isBlank(m.Module_Code__c) ? m.DeveloperName : m.Module_Code__c;
            if (!bestScore.containsKey(code) || score > bestScore.get(code)) {
                best.put(code, m);
                bestScore.put(code, score);
            }
        }

        Set<String> fallbackCodes = new Set<String>();
        for (String code : best.keySet()) {
            Quote_Terms_Module__mdt m = best.get(code);
            ModuleView mv = new ModuleView();
            mv.code = code;
            mv.title = m.Section_Title__c;
            mv.body = m.Body__c;
            mv.placement = String.isBlank(m.Placement__c) ? 'Terms' : m.Placement__c;
            mv.language = m.Language__c;
            mv.sortOrder = m.Sort_Order__c;
            mv.isFallback = m.Language__c != r.language;
            mv.appliesBecause = describeTrigger(m);
            r.modules.add(mv);
            if (mv.isFallback) fallbackCodes.add(code);
        }
        r.modules.sort();
        if (!fallbackCodes.isEmpty()) {
            List<String> codes = new List<String>(fallbackCodes);
            codes.sort();
            r.warnings.add('No ' + r.language + ' text yet for: ' + String.join(codes, ', ') + ' – English is used.');
        }
        return r;
    }

    // ------------------------------------------------------------------------------- helpers
    private static Boolean conditionMatches(Quote_Terms_Module__mdt m, Set<String> groupsLower, Set<String> categoriesLower) {
        String whenValue = String.isBlank(m.Applies_When__c) ? 'Always' : m.Applies_When__c;
        Set<String> wanted = splitLower(m.Condition_Value__c);
        if (whenValue == 'Always') return true;
        if (whenValue == 'Has_Group') return intersects(wanted, groupsLower);
        if (whenValue == 'Has_Category') return intersects(wanted, categoriesLower);
        if (whenValue == 'Only_Category') return categoriesLower.size() == 1 && intersects(wanted, categoriesLower);
        return false;
    }

    private static String describeTrigger(Quote_Terms_Module__mdt m) {
        String whenValue = String.isBlank(m.Applies_When__c) ? 'Always' : m.Applies_When__c;
        String v = String.isBlank(m.Condition_Value__c) ? '' : m.Condition_Value__c.replace(';', ', ').replace('_', ' ');
        String text;
        if (whenValue == 'Always') text = 'Always';
        else if (whenValue == 'Has_Group') text = 'Product: ' + v;
        else if (whenValue == 'Has_Category') text = 'Any ' + v.toLowerCase();
        else text = 'Only ' + v.toLowerCase();
        if (String.isNotBlank(m.Exclude_Groups__c)) {
            text += ' (not if quote has ' + m.Exclude_Groups__c.replace(';', ', ').replace('_', ' ') + ')';
        }
        return text;
    }

    private static Boolean isAll(String semicolonList) {
        return String.isBlank(semicolonList) || splitLower(semicolonList).contains('all');
    }

    private static Set<String> splitLower(String semicolonList) {
        Set<String> out = new Set<String>();
        if (String.isBlank(semicolonList)) return out;
        for (String v : semicolonList.split(';')) if (String.isNotBlank(v)) out.add(v.trim().toLowerCase());
        return out;
    }

    private static Boolean intersects(Set<String> a, Set<String> b) {
        for (String x : a) if (b.contains(x)) return true;
        return false;
    }

    private static Set<String> lower(Set<String> values) {
        Set<String> out = new Set<String>();
        for (String v : values) out.add(v.toLowerCase());
        return out;
    }

    public class QuoteTermsException extends Exception {}
}