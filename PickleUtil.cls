global class PickleUtil {
    // Returns the SObject name given its label (singluar or plural)    
    Map<String, String> sobjectLabel2name;
    public String getSObjectName(String label) {
        if (sobjectLabel2name != null) return sobjectLabel2name.get(label);
        
        sobjectLabel2name = new Map<String, String>();
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        Schema.DescribeSObjectResult sor;

        for (String s : gd.keySet()) {
            sor = gd.get(s).getDescribe();
            sobjectLabel2name.put(sor.getLabel(), s);
            sobjectLabel2name.put(sor.getLabelPlural(), s);
        }
        return sobjectLabel2name.get(label);
    }
}
