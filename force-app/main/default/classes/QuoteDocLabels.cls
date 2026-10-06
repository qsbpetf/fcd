/**
 * English / German labels used by the offer PDF and the generated Terms & Conditions.
 */
public with sharing class QuoteDocLabels {

    private static final Map<String, List<String>> TEXT = new Map<String, List<String>>{
        'offer'            => new List<String>{ 'Offer', 'Angebot' },
        'bindingOffer'     => new List<String>{ 'Binding quote', 'Verbindliches Angebot' },
        'nonBindingOffer'  => new List<String>{ 'Non-binding offer', 'Unverbindliches Angebot' },
        'basicInfo'        => new List<String>{ 'Offer details', 'Angebotsdetails' },
        'quoteNumber'      => new List<String>{ 'Quote number', 'Angebotsnummer' },
        'quoteName'        => new List<String>{ 'Quote name', 'Angebotsname' },
        'createdDate'      => new List<String>{ 'Created date', 'Erstellt am' },
        'expirationDate'   => new List<String>{ 'Expiration date', 'Gültig bis' },
        'paymentTerms'     => new List<String>{ 'Payment terms', 'Zahlungsbedingungen' },
        'customerDetails'  => new List<String>{ 'Customer details', 'Kundenangaben' },
        'companyName'      => new List<String>{ 'Company name', 'Firma' },
        'vatTaxId'         => new List<String>{ 'VAT / Tax ID', 'USt-IdNr.' },
        'contactName'      => new List<String>{ 'Contact name', 'Ansprechpartner' },
        'invoiceContact'   => new List<String>{ 'Invoice contact', 'Rechnungskontakt' },
        'billingAddress'   => new List<String>{ 'Billing address', 'Rechnungsadresse' },
        'shippingAddress'  => new List<String>{ 'Shipping address', 'Lieferadresse' },
        'productLines'     => new List<String>{ 'Product lines', 'Positionen' },
        'product'          => new List<String>{ 'Product', 'Produkt' },
        'quantity'         => new List<String>{ 'Quantity', 'Menge' },
        'additionalInfo'   => new List<String>{ 'Additional info', 'Zusatzinformation' },
        'unitOfMeasure'    => new List<String>{ 'Unit', 'Einheit' },
        'discount'         => new List<String>{ 'Discount', 'Rabatt' },
        'total'            => new List<String>{ 'Total', 'Gesamt' },
        'issuedBy'         => new List<String>{ 'Eficode entity', 'Eficode Gesellschaft' },
        'unitPrice'        => new List<String>{ 'Unit price', 'Einzelpreis' },
        'salesPrice'       => new List<String>{ 'Sales price', 'Verkaufspreis' },
        'start'            => new List<String>{ 'Start', 'Beginn' },
        'end'              => new List<String>{ 'End', 'Ende' },
        'totalListPrice'   => new List<String>{ 'Total list price', 'Listenpreis gesamt' },
        'totalDiscount'    => new List<String>{ 'Total discount', 'Rabatt gesamt' },
        'totalSalesPrice'  => new List<String>{ 'Total sales price', 'Gesamtpreis' },
        'orderAcceptance'  => new List<String>{ 'Order acceptance', 'Auftragsbestätigung' },
        'name'             => new List<String>{ 'Name', 'Name' },
        'jobTitle'         => new List<String>{ 'Job title', 'Position' },
        'date'             => new List<String>{ 'Date', 'Datum' },
        'signature'        => new List<String>{ 'Signature', 'Unterschrift' },
        'poNumber'         => new List<String>{ 'PO number', 'Bestellnummer' },
        'eficodeDetails'   => new List<String>{ 'Eficode details', 'Eficode Unternehmensangaben' },
        'preparedBy'       => new List<String>{ 'Prepared by', 'Erstellt von' },
        'email'            => new List<String>{ 'Email', 'E-Mail' },
        'bespokeTerms'     => new List<String>{ 'Bespoke Quote Terms', 'Individuelle Vereinbarungen' },
        'governedBy'       => new List<String>{ 'This offer is governed by', 'Dieses Angebot unterliegt' },
        'dated'            => new List<String>{ 'dated', 'vom' },
        'termsConditions'  => new List<String>{ 'Terms & Conditions', 'Geschäftsbedingungen und Konditionen' },
        'additionalTerms'  => new List<String>{ 'Additional Terms and Conditions as applicable', 'Zusätzliche Geschäftsbedingungen, sofern zutreffend' },
        'businessId'       => new List<String>{ 'Business ID', 'Business ID' },
        'vatId'            => new List<String>{ 'VAT', 'USt-IdNr.' },
        'managingDirector' => new List<String>{ 'Managing Director', 'Geschäftsführer' },
        'page'             => new List<String>{ 'Page', 'Seite' }
    };

    public static Map<String, String> get(Boolean german) {
        Map<String, String> out = new Map<String, String>();
        for (String k : TEXT.keySet()) out.put(k, TEXT.get(k)[german ? 1 : 0]);
        return out;
    }

    public static String formatDate(Date d, Boolean german) {
        if (d == null) return '';
        return Datetime.newInstanceGmt(d.year(), d.month(), d.day()).formatGmt(german ? 'dd.MM.yyyy' : 'd MMMM yyyy');
    }
}