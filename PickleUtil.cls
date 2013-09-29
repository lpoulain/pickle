global class PickleUtil {
    Pickle myPickle;
    Public PickleUtil(Pickle p) { SObjectMap = new Map<String, SObjectInfo>(); myPickle = p; }

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
    
    // SObject metadata field information
    Map<String, SObjectInfo> SObjectMap;
    public SObjectInfo getSObjectInfo(String objectName) {
        if (!SObjectMap.containsKey(objectName)) {
            SObjectInfo soi = new SObjectInfo(objectName, myPickle);
            SObjectMap.put(objectName, soi);
            return soi;
        }
        return SObjectMap.get(objectName);
    }
    
    public class SObjectInfo {
        String objectName;
        Pickle myPickle;
        Map<String, Schema.SObjectField> objectFields;
        Map<String, String> fieldLabel2name;
        Map<String, DisplayType> fieldName2type;
        Schema.SObjectType objectType;
        
        public SObjectInfo(String name, Pickle p) {
            DisplayType dt;
            objectName = name;
            myPickle = p;
        
            objectType = Schema.getGlobalDescribe().get(objectName);
            Schema.DescribeSObjectResult F = objectType.getDescribe();
            objectFields = F.fields.getMap();
            fieldLabel2name = new Map<String, String>();
            fieldName2type = new Map<String, DisplayType>();
            
            for (SObjectField sof : objectFields.values()) {
                Schema.DescribeFieldResult dfr = sof.getDescribe();
                fieldLabel2name.put(dfr.getLabel().toLowerCase(), dfr.getName());
                fieldName2type.put(dfr.getName().toLowerCase(), dfr.getType());
            }
        }

        public Set<String> getFieldLabels() { return fieldLabel2name.keySet(); }

        public SObject instanciate() { return objectType.newSObject(); }
        
        public String getFieldName(String fieldLabel) {
            if (!fieldLabel2name.containsKey(fieldLabel)) myPickle.error('Unknown field "' + fieldLabel + '" for object "' + objectName + '"');
            return fieldLabel2name.get(fieldLabel);
        }
        
        public DisplayType getFieldType(String fieldName) {
            if (!fieldname2type.containsKey(fieldName)) myPickle.error('Unknown field "' + fieldName + '" for object "' + objectName + '"');
            return fieldname2type.get(fieldName);
        }
        
        public List<FieldConversion> getConversionList(List<String> fieldNames) {
            List<FieldConversion> res = new List<FieldConversion>();
            DisplayType dt;
            
            for (String fieldName : fieldNames) {
                dt = fieldName2type.get(fieldName.toLowerCase());
                if (dt == DisplayType.Reference || dt == DisplayType.Id) res.add(new FieldConversionId(myPickle));
                else if (dt == DisplayType.String || dt == DisplayType.picklist || dt == DisplayType.textarea) res.add(new FieldConversionString());
                else if (dt == DisplayType.Currency || dt == DisplayType.Double || dt == DisplayType.Percent || dt == DisplayType.Integer) res.add(new FieldConversionNumber());
                else if (dt == DisplayType.Boolean) res.add(new FieldConversionBoolean());
                else if (dt == DisplayType.Date) res.add(new FieldConversionDate());
                else if (dt == DisplayType.Datetime) res.add(new FieldConversionDatetime());            
                else myPickle.error('Unsupported type "' + String.valueOf(dt) + '" for field "' + fieldName + '" for object "' + objectName + '"');
            }
            
            return res;
        }
    }
 
    public abstract class FieldConversion {
        public abstract Object convert(String s);
    }
    class FieldConversionId extends FieldConversion {
        Pickle myPickle;
        FieldConversionId(Pickle p) { myPickle = p; }
        public override Object convert(String s) { return myPickle.getSObjectId(s); }
    }
    class FieldConversionString extends FieldConversion {
        public override Object convert(String s) { return s; }
    }
    class FieldConversionNumber extends FieldConversion {
        public override Object convert(String s) { return Double.valueOf(s); }
    }
    class FieldConversionBoolean extends FieldConversion {
        public override Object convert(String s) { return (s == 'true'); }
    }
    class FieldConversionDate extends FieldConversion {
        public override Object convert(String s) { return Date.valueOf(s); }
    }
    class FieldConversionDatetime extends FieldConversion {
        public override Object convert(String s) { return Datetime.valueOf(s); }
    }
<<<<<<< HEAD
}
=======
}
>>>>>>> 569eb8ded94fb3d41f9e34ef263e0ca2f8585c04
