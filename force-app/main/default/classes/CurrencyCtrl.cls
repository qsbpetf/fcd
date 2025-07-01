/**
 * Created by peterfriberg on 2025-05-02.
 */

public with sharing class CurrencyCtrl {

    private static final String ACCESS_KEY = '15dc0ea87ee000160ae74e3a722fa1d6';

    public static final Map<String, String> CURRENCY_ISO_CODES_TO_NAME = new Map<String, String> {
        'AED' => 'United Arab Emirates dirham',
        'AFN' => 'Afghan afghani',
        'ALL' => 'Albanian lek',
        'AMD' => 'Armenian dram',
        'ANG' => 'Netherlands Antillean guilder',
        'AOA' => 'Angolan kwanza',
        'ARS' => 'Argentine peso',
        'AUD' => 'Australian dollar',
        'AWG' => 'Aruban florin',
        'AZN' => 'Azerbaijani manat',
        'BAM' => 'Bosnia and Herzegovina convertible mark',
        'BBD' => 'Barbadian dollar',
        'BDT' => 'Bangladeshi taka',
        'BGN' => 'Bulgarian lev',
        'BHD' => 'Bahraini dinar',
        'BIF' => 'Burundian franc',
        'BMD' => 'Bermudian dollar',
        'BND' => 'Brunei dollar',
        'BOB' => 'Bolivian boliviano',
        'BRL' => 'Brazilian real',
        'BSD' => 'Bahamian dollar',
        'BTC' => 'Bitcoin',
        'BTN' => 'Bhutanese ngultrum',
        'BWP' => 'Botswana pula',
        'BYN' => 'Belarusian ruble',
        'BYR' => 'Belarusian ruble (2000–2016)',
        'BZD' => 'Belize dollar',
        'CAD' => 'Canadian dollar',
        'CDF' => 'Congolese franc',
        'CHF' => 'Swiss franc',
        'CLF' => 'Unidad de Fomento (funds code)',
        'CLP' => 'Chilean peso',
        'CNY' => 'Chinese yuan',
        'CNH' => 'Chinese yuan (offshore)',
        'COP' => 'Colombian peso',
        'CRC' => 'Costa Rican colón',
        'CUC' => 'Cuban convertible peso',
        'CUP' => 'Cuban peso',
        'CVE' => 'Cape Verdean escudo',
        'CZK' => 'Czech koruna',
        'DJF' => 'Djiboutian franc',
        'DKK' => 'Danish krone',
        'DOP' => 'Dominican peso',
        'DZD' => 'Algerian dinar',
        'EGP' => 'Egyptian pound',
        'ERN' => 'Eritrean nakfa',
        'ETB' => 'Ethiopian birr',
        'EUR' => 'Euro',
        'FJD' => 'Fijian dollar',
        'FKP' => 'Falkland Islands pound',
        'GBP' => 'British pound',
        'GEL' => 'Georgian lari',
        'GGP' => 'Guernsey pound',
        'GHS' => 'Ghanaian cedi',
        'GIP' => 'Gibraltar pound',
        'GMD' => 'Gambian dalasi',
        'GNF' => 'Guinean franc',
        'GTQ' => 'Guatemalan quetzal',
        'GYD' => 'Guyanese dollar',
        'HKD' => 'Hong Kong dollar',
        'HNL' => 'Honduran lempira',
        'HRK' => 'Croatian kuna',
        'HTG' => 'Haitian gourde',
        'HUF' => 'Hungarian forint',
        'IDR' => 'Indonesian rupiah',
        'ILS' => 'Israeli new shekel',
        'IMP' => 'Isle of Man pound',
        'INR' => 'Indian rupee',
        'IQD' => 'Iraqi dinar',
        'IRR' => 'Iranian rial',
        'ISK' => 'Icelandic króna',
        'JEP' => 'Jersey pound',
        'JMD' => 'Jamaican dollar',
        'JOD' => 'Jordanian dinar',
        'JPY' => 'Japanese yen',
        'KES' => 'Kenyan shilling',
        'KGS' => 'Kyrgyzstani som',
        'KHR' => 'Cambodian riel',
        'KMF' => 'Comorian franc',
        'KPW' => 'North Korean won',
        'KRW' => 'South Korean won',
        'KWD' => 'Kuwaiti dinar',
        'KYD' => 'Cayman Islands dollar',
        'KZT' => 'Kazakhstani tenge',
        'LAK' => 'Lao kip',
        'LBP' => 'Lebanese pound',
        'LKR' => 'Sri Lankan rupee',
        'LRD' => 'Liberian dollar',
        'LSL' => 'Lesotho loti',
        'LTL' => 'Lithuanian litas',
        'LVL' => 'Latvian lats',
        'LYD' => 'Libyan dinar',
        'MAD' => 'Moroccan dirham',
        'MDL' => 'Moldovan leu',
        'MGA' => 'Malagasy ariary',
        'MKD' => 'Macedonian denar',
        'MMK' => 'Myanmar kyat',
        'MNT' => 'Mongolian tögrög',
        'MOP' => 'Macanese pataca',
        'MRU' => 'Mauritanian ouguiya',
        'MUR' => 'Mauritian rupee',
        'MVR' => 'Maldivian rufiyaa',
        'MWK' => 'Malawian kwacha',
        'MXN' => 'Mexican peso',
        'MYR' => 'Malaysian ringgit',
        'MZN' => 'Mozambican metical',
        'NAD' => 'Namibian dollar',
        'NGN' => 'Nigerian naira',
        'NIO' => 'Nicaraguan córdoba',
        'NOK' => 'Norwegian krone',
        'NPR' => 'Nepalese rupee',
        'NZD' => 'New Zealand dollar',
        'OMR' => 'Omani rial',
        'PAB' => 'Panamanian balboa',
        'PEN' => 'Peruvian sol',
        'PGK' => 'Papua New Guinean kina',
        'PHP' => 'Philippine peso',
        'PKR' => 'Pakistani rupee',
        'PLN' => 'Polish złoty',
        'PYG' => 'Paraguayan guaraní',
        'QAR' => 'Qatari riyal',
        'RON' => 'Romanian leu',
        'RSD' => 'Serbian dinar',
        'RUB' => 'Russian ruble',
        'RWF' => 'Rwandan franc',
        'SAR' => 'Saudi riyal',
        'SBD' => 'Solomon Islands dollar',
        'SCR' => 'Seychellois rupee',
        'SDG' => 'Sudanese pound',
        'SEK' => 'Swedish krona',
        'SGD' => 'Singapore dollar',
        'SHP' => 'Saint Helena pound',
        'SLE' => 'Sierra Leonean leone',
        'SLL' => 'Sierra Leonean leone (before redenomination)',
        'SOS' => 'Somali shilling',
        'SRD' => 'Surinamese dollar',
        'STD' => 'São Tomé and Príncipe dobra (before redenomination)',
        'SVC' => 'Salvadoran colón',
        'SYP' => 'Syrian pound',
        'SZL' => 'Swazi lilangeni',
        'THB' => 'Thai baht',
        'TJS' => 'Tajikistani somoni',
        'TMT' => 'Turkmenistani manat',
        'TND' => 'Tunisian dinar',
        'TOP' => 'Tongan paʻanga',
        'TRY' => 'Turkish lira',
        'TTD' => 'Trinidad and Tobago dollar',
        'TWD' => 'New Taiwan dollar',
        'TZS' => 'Tanzanian shilling',
        'UAH' => 'Ukrainian hryvnia',
        'UGX' => 'Ugandan shilling',
        'USD' => 'United States dollar',
        'UYU' => 'Uruguayan peso',
        'UZS' => 'Uzbekistani som',
        'VES' => 'Venezuelan bolívar soberano',
        'VND' => 'Vietnamese đồng',
        'VUV' => 'Vanuatu vatu',
        'WST' => 'Samoan tālā',
        'XAF' => 'Central African CFA franc',
        'XAG' => 'Silver (one troy ounce)',
        'XAU' => 'Gold (one troy ounce)',
        'XCD' => 'East Caribbean dollar',
        'XDR' => 'Special drawing rights',
        'XOF' => 'West African CFA franc',
        'XPF' => 'CFP franc',
        'YER' => 'Yemeni rial',
        'ZAR' => 'South African rand',
        'ZMK' => 'Zambian kwacha (before 2013)',
        'ZMW' => 'Zambian kwacha',
        'ZWL' => 'Zimbabwean dollar'
    };


    /**
     * @description Updates DatedConversionRate records for all managed currencies
     * using the latest exchange rates from the API with applied markups.
     */
    public static void updateCurrencyConversionRates() {
        // Step 1: Get managed currencies
        Map<String, CurrencyType> managedCurrencies = getManagedCurrencies();

        // Step 2: Get the latest exchange rates
        CurrencyWrapper currencyWrap = getRates();
        if (currencyWrap == null) {
            System.debug('Failed to retrieve currency rates from the API');
            return;
        }

        // Step 3: Flatten currencies
        flattenCurrencies(currencyWrap, managedCurrencies.keySet());

        // Step 4: Apply markups to the rates
        Map<String, Double> markedUpRates = getMarkedUpRatesBasedOnCorporateCurrency(currencyWrap.flatRates);

        // Step 5: Get corporate currency (this will be our base)
        CurrencyType corporateCurrency = getCorporateCurrency();
        if (corporateCurrency == null) {
            System.debug('Corporate currency not found');
            return;
        }

        // Step 6: Create DatedConversionRate records
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        Date effectiveDate = Date.today(); // Use today's date for the conversion rates

        for (String currencyCode : markedUpRates.keySet()) {
            // Skip the corporate currency as it doesn't need a conversion rate to itself
            if (currencyCode != corporateCurrency.IsoCode && managedCurrencies.containsKey(currencyCode)) {
                records.add(new Map<String, Object>{
                    'attributes' => new Map<String, String>{ 'type' => 'DatedConversionRate', 'referenceId' => currencyCode + 'Rate' },
                    'IsoCode' => currencyCode,
                    'StartDate' => effectiveDate.format(),
                    'ConversionRate' => markedUpRates.get(currencyCode)
                });
            }
        }

        // Step 7: Insert the records
        if (!records.isEmpty()) {

            Map<String, Object> requestBody = new Map<String, Object>{
                'allOrNone' => true,
                'records' => records
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint(Url.getOrgDomainUrl().toExternalForm() + '/services/data/v63.0/composite/sobjects');
            req.setMethod('POST');
            req.setHeader('Authorization', 'OAuth ' + UserInfo.getSessionId());
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(requestBody));

            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('Status: ' + res.getStatusCode());
            System.debug('Response: ' + res.getBody());

        } else {
            System.debug('No DatedConversionRate records to insert');
        }

        // Step 8: Apply markups to the rates for Atlassian PPC with USD as base currency
        markedUpRates = getMarkedUpRatesBasedOnIsoCurrencyCode(currencyWrap.flatRates, 'USD');

        // Step 9: Create custom object Exchange Rate records
        List<Buying_Exchange_Rate__c> exchangeRates = new List<Buying_Exchange_Rate__c>();

        for (String currencyCode : markedUpRates.keySet()) {
            // Skip the corporate currency as it doesn't need a conversion rate to itself
            if (currencyCode != 'USD' && managedCurrencies.containsKey(currencyCode)) {
                Buying_Exchange_Rate__c exchangeRate = new Buying_Exchange_Rate__c(
                    CurrencyIsoCode = currencyCode,
                    Exchange_Rate_from_USD_to_X__c = Double.valueOf(Math.round(markedUpRates.get(currencyCode) * 10000)) / 10000,
                    Start_Date__c = effectiveDate,
                    Start_Date_Unique__c = effectiveDate.format() + currencyCode);
                exchangeRates.add(exchangeRate);
                System.debug('ADDING: ' + exchangeRate);
                // insert exchangeRate;
            }
        }

        // Step 10: Insert the custom object records
        System.debug('EXCHANGE RATES TO INSERT: ' + exchangeRates);
        insert exchangeRates;
    }

    /**
     * @description Get the marked-up rates for the given flat rates.
     *
     * @param flatRates List of FlatRate objects containing the rates and currency codes.
     * @return Map of ISO currency codes to their marked-up rates.
     */
    public static Map<String, Double> getMarkedUpRatesBasedOnCorporateCurrency(List<FlatRate> flatRates) {
        Map<String, CurrencyRateMarkup__mdt> markupsByCurrency = CurrencyRateMarkup__mdt.getAll();
        Decimal defaultMarkupPercent = markupsByCurrency.get('Default').MarkupPercent__c;

        Map<String, Double> markedUpRates = new Map<String, Double>();
        for (FlatRate rate : flatRates) {
            if (!rate.isBase) {
                // Get the markup percent for the currency, defaulting to the global default if not found
                Decimal markupPercent = defaultMarkupPercent;
                if (markupsByCurrency.containsKey(rate.isoCurrencyCode)) {
                    markupPercent = markupsByCurrency.get(rate.isoCurrencyCode).MarkupPercent__c;
                }
                markedUpRates.put(rate.isoCurrencyCode, rate.rate * (1 + markupPercent / 100));
                System.debug('*** USING: ' + rate.isoCurrencyCode + ' with markup: ' + markupPercent + '%');
            } else {
                // Base currency is not marked up
                markedUpRates.put(rate.isoCurrencyCode, rate.rate);
            }
        }
        return markedUpRates;
    }

    public static Map<String, Double> getMarkedUpRatesBasedOnIsoCurrencyCode(List<FlatRate> flatRates, String isoCurrencyCode) {
        Map<String, CurrencyRateMarkup__mdt> markupsByCurrency = CurrencyRateMarkup__mdt.getAll();
        Decimal defaultMarkupPercent = markupsByCurrency.get('Default').MarkupPercent__c;

        Double baseRate = 1;
        for (FlatRate rate : flatRates) {
            if (rate.isoCurrencyCode.equals(isoCurrencyCode)) {
                baseRate = rate.rate;
                System.debug('*** Base currency found: ' + rate.isoCurrencyCode + ' with rate: ' + baseRate);
                break;
            }
        }

        Map<String, Double> markedUpRates = new Map<String, Double>();
        for (FlatRate rate : flatRates) {
            if (!rate.isoCurrencyCode.equals(isoCurrencyCode)) {
                // Get the markup percent for the currency, defaulting to the global default if not found
                Decimal markupPercent = defaultMarkupPercent;
                if (markupsByCurrency.containsKey(rate.isoCurrencyCode)) {
                    markupPercent = markupsByCurrency.get(rate.isoCurrencyCode).MarkupPercent__c;
                }
                markedUpRates.put(rate.isoCurrencyCode, rate.rate * (1 + markupPercent / 100) / baseRate);
                System.debug('*** USING: ' + rate.isoCurrencyCode + ' clean rate: ' + rate.rate / baseRate);
                System.debug('           ' + rate.isoCurrencyCode + ' with markup: ' + markupPercent + '%');
            } else {
                // Base currency is not marked up
                markedUpRates.put(rate.isoCurrencyCode, rate.rate / baseRate);
                System.debug('*** USING: ' + rate.isoCurrencyCode + ' STD. without markup');
            }
        }
        return markedUpRates;
    }

    /**
     * @description Fetch the latest exchange rates from the external API.
     *
     * @return CurrencyWrapper object containing the exchange rates and metadata.
     */
    public static CurrencyWrapper getRates() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ExchangeRatesAPI/v1/latest?access_key=' + ACCESS_KEY + '&format=1');
        req.setMethod('GET');
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            String jsonText = res.getBody().replace('"date"', '"theDate"');
            CurrencyWrapper wrapper = (CurrencyWrapper) JSON.deserialize(jsonText, CurrencyWrapper.class);
            if (wrapper.success) {
                wrapper.theDateTime = Datetime.newInstance(wrapper.timestamp * 1000L);
                return wrapper;
            }
        }
        return null;
    }

    /**
     * @description Flatten the currency rates into a list of FlatRate objects.
     *
     * @param wrapper CurrencyWrapper object containing the rates and base currency.
     * @param managedCurrencies Set of ISO currency codes that are managed.
     */
    public static void flattenCurrencies(CurrencyWrapper wrapper, Set<String> managedCurrencies) {
        wrapper.currencyNames = CURRENCY_ISO_CODES_TO_NAME;
        wrapper.flatRates = new List<FlatRate>();
        for (String curr : wrapper.rates.keySet()) {
            if (managedCurrencies.contains(curr)) {
                wrapper.flatRates.add(
                    new FlatRate(
                        curr,
                        wrapper.rates.get(curr),
                        managedCurrencies.contains(curr),
                        curr.equals(wrapper.base)
                    )
                );
            }
        }
    }

    /**
     * @description Get a map of all managed currencies in Salesforce with their ISO codes as keys.
     *
     * @return Map of ISO currency codes to CurrencyType objects.
     */
    public static Map<String, CurrencyType> getManagedCurrencies() {
        Map<String, CurrencyType> managedCurrencies = new Map<String, CurrencyType>();
        List<CurrencyType> currencies = new List<CurrencyType>([
            SELECT
                IsActive,
                IsCorporate,
                IsoCode
            FROM CurrencyType
            ORDER BY IsoCode
        ]);
        for (CurrencyType curr : currencies) {
            managedCurrencies.put(curr.IsoCode, curr);
        }
        return managedCurrencies;
    }

    /**
     * @description Get the corporate currency from the managed currencies.
     *
     * @return CurrencyType object representing the corporate currency, or null if not found.
     */
    public static CurrencyType getCorporateCurrency() {
        Map<String, CurrencyType> currencies = getManagedCurrencies();
        for (CurrencyType curr : currencies.values()) {
            if (curr.IsCorporate) {
                return curr;
            }
        }
        return null;
    }

    // =========================================================
    // Inner classes for the CurrencyWrapper and FlatRate objects
    // =========================================================

    public class CurrencyWrapper {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Long timestamp;
        @AuraEnabled public Datetime theDateTime;
        @AuraEnabled public String base;
        @AuraEnabled public String theDate;
        @AuraEnabled public Map<String, Double> rates;
        @AuraEnabled public List<FlatRate> flatRates;
        @AuraEnabled public List<FlatRate> adjustedFlatRates;
        @AuraEnabled public Map<String, String> currencyNames;
    }

    public class FlatRate {
        @AuraEnabled public String isoCurrencyCode;
        @AuraEnabled public String currencyName;
        @AuraEnabled public Double rate;
        @AuraEnabled public Boolean managed;
        @AuraEnabled public Boolean isBase;

        public FlatRate(String isoCurrencyCode, Double rate, Boolean managed, Boolean isBase) {
            this.isoCurrencyCode = isoCurrencyCode;
            this.currencyName = isoCurrencyCode + '  -  ' + CURRENCY_ISO_CODES_TO_NAME.get(isoCurrencyCode);
            this.rate = rate;
            this.managed = managed;
            this.isBase = isBase;
        }
    }
}