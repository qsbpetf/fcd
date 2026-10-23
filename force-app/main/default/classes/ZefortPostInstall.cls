global class ZefortPostInstall implements InstallHandler {
    global void onInstall(InstallContext context) {
        if(context.previousVersion() == null) {
            // This is a new installation
            createDefaultSettings();
        } else {
            // This is an upgrade
            // For upgrades, we don't change existing configured settings
            Version previousVersion = context.previousVersion();
            
            // Check if upgrading from a version before 1.0
            if (previousVersion.compareTo(new Version(1, 0)) < 0) {
                // If upgrading from a previous version, ensure settings exist
                ensureSettingsExist();
            }
        }
    }
    
    private void createDefaultSettings() {
        // Create default settings record if it doesn't exist
        ZefortSettings__c settings = ZefortSettings__c.getOrgDefaults();
        
        if (settings.Id == null) {
            settings = new ZefortSettings__c();
        }
        
        // Set default values for a new installation
        try {
            settings.put('Region__c', 'sandbox');
        } catch (Exception e) {
            // Field might not exist yet; will be handled later by UI
            System.debug('Error setting Region__c: ' + e.getMessage());
        }
        
        upsert settings;
    }
    
    private void ensureSettingsExist() {
        // Make sure settings record exists after upgrade
        ZefortSettings__c settings = ZefortSettings__c.getOrgDefaults();
        
        if (settings.Id == null) {
            settings = new ZefortSettings__c();
            
            // For upgrades, set default values only if settings don't exist
            try {
                settings.put('Region__c', 'sandbox');
            } catch (Exception e) {
                // Field might not exist yet; will be handled later by UI
                System.debug('Error setting Region__c: ' + e.getMessage());
            }
            
            insert settings;
        }
    }
}