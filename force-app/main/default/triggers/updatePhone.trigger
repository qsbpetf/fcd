trigger updatePhone on Contact (before insert, before update) {
    Integer countPhone;
    Integer countMobile;
    Integer countDDI;
    for(Contact con : trigger.new) {
        if(con.Phone != null) {
            countPhone = 0;
            for(Integer i=0; i<con.Phone.length(); i++) {
                if(con.Phone.subString(i, i+1).isNumeric()) {
                    countPhone++;
                }
            }
        }
        if(con.MobilePhone != null) {
            countMobile = 0;
            for(Integer i=0; i<con.MobilePhone.length(); i++) {
                if(con.MobilePhone.subString(i, i+1).isNumeric()) {
                    countMobile++;
                }
            }
        }
        if(con.DDI__c != null) {
            countDDI = 0;
            for(Integer i=0; i<con.DDI__c.length(); i++) {
                if(con.DDI__c.subString(i, i+1).isNumeric()) {
                    countDDI++;
                }
            }
        }
        if(countPhone >= 5 || countMobile >=5 || countDDI >=5) {
            //Replace Has_Phone__c with API name of field
            con.Has_Phone__c = true;
        }
        else {
            //Replace Has_Phone__c with API name of field
            con.Has_Phone__c = false;
        }
    }
}