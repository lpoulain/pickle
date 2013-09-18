public class PickleStatementDataLoader extends Pickle.StatementType {
    abstract class fieldConversion {
        public abstract Object convert(String s);
    }
    class fieldConversionId extends fieldConversion {
        Pickle myPickle;
        fieldConversionId(Pickle p) { myPickle = p; }
        public override Object convert(String s) { return myPickle.getSObjectId(s); }
    }
    class fieldConversionString extends fieldConversion {
        public override Object convert(String s) { return s; }
    }
    class fieldConversionNumber extends fieldConversion {
        public override Object convert(String s) { return Double.valueOf(s); }
    }
    class fieldConversionBoolean extends fieldConversion {
        public override Object convert(String s) { return (s == 'true'); }
    }
    class fieldConversionDate extends fieldConversion {
        public override Object convert(String s) { return Date.valueOf(s); }
    }
    class fieldConversionDatetime extends fieldConversion {
        public override Object convert(String s) { return Datetime.valueOf(s); }
    }

    public PickleStatementDataLoader(Pickle p) { super(p, 'the following "(.*)" exist:'); }
    public override Boolean execute(List<String> args) {
        System.debug('Step THE FOLLOWING "' + args[0] + '" exist:');
        String statement;
        String objectName = myPickle.objectLabel2name(args[0]);
        if (objectName == null) throw new Pickle.PickleException('Object "' + args[0] + '" unknown');

        if (!myPickle.hasNextStatement()) return true;
        statement = myPickle.nextStatement();
        if (statement == '') return true;
        Integer i;
        DisplayType dt;
        
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult F = objectType.getDescribe();
        Map<String, Schema.SObjectField> objectFields = F.fields.getMap();
        Map<String, String> label2name = new Map<String, String>();
        Map<String, DisplayType> name2type = new Map<String, DisplayType>();
        for (SObjectField sof : objectFields.values()) {
            Schema.DescribeFieldResult dfr = sof.getDescribe();
            label2name.put(dfr.getLabel().toLowerCase(), dfr.getName());
            name2type.put(dfr.getName().toLowerCase(), dfr.getType());
        }
        System.debug(label2name);
        sObject obj;

        String fieldName;
        List<String> recordFieldLabels = statement.split('\\|');
        List<String> recordFieldNames = new List<String>();
        List<String> recordFieldValues;
        List<fieldConversion> recordFieldConversion = new List<fieldConversion>();
        List<String> stmtIds = new List<String>();
        List<SObject> objects = new List<SObject>();

        for (String fieldLabel : recordFieldLabels) {
            fieldLabel = fieldLabel.toLowerCase();
            fieldName = label2name.get(fieldLabel);
            if (fieldName == null) throw new Pickle.PickleException('Unknown field "' + fieldLabel + '" for object "' + args[0] + '"');
            recordFieldNames.add(fieldName);
            dt = name2type.get(fieldName.toLowerCase());
            if (dt == DisplayType.Reference || dt == DisplayType.Id) recordFieldConversion.add(new fieldConversionId(myPickle));
            else if (dt == DisplayType.String || dt == DisplayType.picklist || dt == DisplayType.textarea) recordFieldConversion.add(new fieldConversionString());
            else if (dt == DisplayType.Currency || dt == DisplayType.Double || dt == DisplayType.Percent || dt == DisplayType.Integer) recordFieldConversion.add(new fieldConversionNumber());
            else if (dt == DisplayType.Boolean) recordFieldConversion.add(new fieldConversionBoolean());
            else if (dt == DisplayType.Date) recordFieldConversion.add(new fieldConversionDate());
            else if (dt == DisplayType.Datetime) recordFieldConversion.add(new fieldConversionDatetime());            
            else throw new Pickle.PickleException('Unsupported type "' + String.valueOf(dt) + '" for field "' + fieldLabel + '" for object "' + args[0] + '"');
        }

        while (myPickle.hasNextStatement()) {
            statement = myPickle.nextStatement();
            if (statement == '') return true;

            obj = objectType.newsObject();
            objects.add(obj);
            recordFieldValues = statement.split('\\|');
            for (i=0; i<recordFieldNames.size(); i++) {
                if (i >= recordFieldValues.size()) throw new Pickle.PickleException('Not enough columns for object "' + args[0] + '" at row: (' + statement + ')');
                if (name2type.get(recordFieldNames[i].toLowerCase()) == DisplayType.ID) {
                    stmtIds.add(recordFieldValues[i]);
                } else {
                    System.debug(logginglevel.error, recordFieldNames[i].toLowerCase());
                    obj.put(recordFieldNames[i].toLowerCase(), recordFieldConversion[i].convert(recordFieldValues[i]));
                }
            }

            System.debug(objects);
            System.debug(stmtIds);
            insert objects;
            for (i=0; i<objects.size(); i++) myPickle.addSObjectId(stmtIds[i], objects[i].Id);
        }
        return true;
    }
}
