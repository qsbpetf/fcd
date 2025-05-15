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

    public static void flattenCurrencies(CurrencyWrapper wrapper, Set<String> managedCurrencies) {
        wrapper.currencyNames = CURRENCY_ISO_CODES_TO_NAME;
        wrapper.flatRates = new List<FlatRate>();
        for (String curr : wrapper.rates.keySet()) {
            if (managedCurrencies.contains(curr)) {
                wrapper.flatRates.add(
                    new FlatRate(
                        curr,
                        wrapper.rates.get(curr),
                        managedCurrencies.contains(curr)
                    )
                );
            }
        }
    }

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

    public static CurrencyType getCorporateCurrency() {
        Map<String, CurrencyType> currencies = getManagedCurrencies();
        for (CurrencyType curr : currencies.values()) {
            if (curr.IsCorporate) {
                return curr;
            }
        }
        return null;
    }

    public class CurrencyWrapper {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Long timestamp;
        @AuraEnabled public Datetime theDateTime;
        @AuraEnabled public String base;
        @AuraEnabled public String theDate;
        @AuraEnabled public Map<String, Double> rates;
        @AuraEnabled public List<FlatRate> flatRates;
        @AuraEnabled public Map<String, String> currencyNames;
    }

    public class FlatRate {
        @AuraEnabled public String isoCurrencyCode;
        @AuraEnabled public String currencyName;
        @AuraEnabled public Double rate;
        @AuraEnabled public Boolean managed;

        public FlatRate(String isoCurrencyCode, Double rate, Boolean managed) {
            this.isoCurrencyCode = isoCurrencyCode;
            this.currencyName = isoCurrencyCode + '  -  ' + CURRENCY_ISO_CODES_TO_NAME.get(isoCurrencyCode);
            this.rate = rate;
            this.managed = managed;
        }
    }
}