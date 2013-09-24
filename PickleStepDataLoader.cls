public class PickleStepDataLoader extends Pickle.StepDefinition {
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

    public PickleStepDataLoader(Pickle p) { super(p, 'the following (.*) exist:'); }
    public override Boolean execute(List<String> args) {
        String line;
        String objectName = myPickle.util.getSObjectName(args[0]);
        if (objectName == null) myPickle.error('Object "' + args[0] + '" unknown');

        if (!myPickle.hasNextLine()) return true;
        line = myPickle.nextLine();
        if (line == '') return true;
        Integer i;
        
        PickleUtil.SObjectInfo soi = myPickle.util.getSObjectInfo(objectName);

        List<String> fieldNames = new List<String>();
        String tmpString;

        for (String s : line.split('\\|')) {
            tmpString = soi.getFieldName(s.trim().toLowerCase());
            fieldNames.add(tmpString);
        }

        sObject obj;
        String fieldName;
        List<String> recordFieldValues;
        List<PickleUtil.FieldConversion> recordFieldConversion = soi.getConversionList(fieldNames);
        List<String> tempIds = new List<String>();
        List<SObject> objects = new List<SObject>();
        
        while (myPickle.hasNextLine()) {
            line = myPickle.nextLine();
            if (line == '') return true;

            obj = soi.instanciate();
            objects.add(obj);
            recordFieldValues = line.split('\\|');
            for (i=0; i<fieldNames.size(); i++) {
                if (i >= recordFieldValues.size()) myPickle.error('Not enough columns for object "' + args[0] + '" at line ' + myPickle.getLineNb() + ' (' + line + ')');
                if (soi.getFieldType(fieldNames[i].toLowerCase()) == DisplayType.ID) {
                    tempIds.add(recordFieldValues[i].trim());
                } else {
//                    System.debug(recordFieldNames[i].toLowerCase());
                    obj.put(fieldNames[i].toLowerCase(), recordFieldConversion[i].convert(recordFieldValues[i].trim()));
                }
            }

            System.debug(objects);
            System.debug(tempIds);
            insert objects;
            for (i=0; i<objects.size(); i++) myPickle.addSObjectId(tempIds[i], objects[i].Id);
        }
        return true;
    }
}
