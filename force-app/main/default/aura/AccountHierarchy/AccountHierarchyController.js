({
    init : function(component, event, helper) {
        helper.checkForParent(component, event, helper);
        helper.checkForChildren(component, event, helper);
    },

    navigateToAccountHierarchy: function(component, event, helper) {
        var acctId = component.get('v.recordId');
        var evt = $A.get("e.force:navigateToComponent");
        evt.setParams({
            componentDef: "sfa:hierarchyFullView",
            componentAttributes: {
                recordId: acctId,
                sObjectName: "Account"	
            }
        });
        evt.fire();
    }
})