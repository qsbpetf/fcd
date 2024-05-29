({
    checkForParent : function(component, event, helper) {
        var action = component.get("c.hasParent");
        var acctId = component.get('v.recordId');
        action.setParams({"accountId": acctId});

        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var result = response.getReturnValue();
                component.set("v.hasParent", result);
            }
        });
        $A.enqueueAction(action);
    },

    checkForChildren : function(component, event, helper) {
        var action = component.get("c.numChildren");
        var acctId = component.get('v.recordId');
        action.setParams({"accountId": acctId});

        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var result = response.getReturnValue();
                component.set("v.numChildren", result);
                if(result == 1) {
                    component.set("v.childOrChildren", "child");
                } else {
                    component.set("v.childOrChildren", "children");
                }
            }
        });
        $A.enqueueAction(action);
    }
})