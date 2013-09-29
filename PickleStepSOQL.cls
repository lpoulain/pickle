public class PickleStepSOQL extends Pickle.StepDefinition {
    public PickleStepSOQL(Pickle p) { super(p, 'the query \\[SELECT (.*) FROM (.*) WHERE (.*)\\] should return:'); }
    public override Boolean execute(List<String> args) {
        System.debug('Step SOQL (SELECT: [' + args[0] + '], FROM: [' + args[1] + '], WHERE: [' + args[2] + '])');
        
        String objectName = myPickle.util.getSObjectName(args[1]);
        if (objectName == null) myPickle.error('Object "' + args[0] + '" unknown');
        
        PickleUtil.SObjectInfo soi = myPickle.util.getSObjectInfo(objectName);

        String soqlSelect = '';
        String soqlFrom = objectName;
        String soqlWhere = args[2];
        String tmpString, fieldLabel, line;

        System.debug(soi.getFieldLabels());
                
        Integer idx = 0, idx2;
        tmpString = '';
        while (idx >= 0) {
            idx2 = soqlWhere.indexOf('"', idx);
            if (idx2 < 0) {
                tmpString += soqlWhere.substring(idx);
                break;
            }
            idx = idx2;
            idx2 = soqlWhere.indexOf('"', idx + 1);
            if (idx2 < 0) {
                tmpString += soqlWhere.substring(idx);
                break;
            }
            fieldLabel = soqlWhere.substring(idx + 1, idx2);
            tmpString += soi.getFieldName(fieldLabel.toLowerCase());
            idx = idx2 + 1;
        }
        soqlWhere = tmpString;

        List<String> fieldNames = new List<String>();
        List<String> fieldLabels = args[0].split(',');
        List<String> recordFieldValues;
        Object fieldValue;

        for (String label : fieldLabels) {
            tmpString = soi.getFieldName(label.toLowercase().trim());
            soqlSelect += ', ' + tmpString;
            fieldNames.add(tmpString);
        }
        List<PickleUtil.FieldConversion> fieldConversion = soi.getConversionList(fieldNames);
        soqlSelect = soqlSelect.substring(1);
        
        System.debug('SELECT ' + soqlSelect + ' FROM ' + soqlFrom + ' WHERE ' + soqlWhere);
        
        for (SObject obj : Database.query('SELECT ' + soqlSelect + ' FROM ' + soqlFrom + ' WHERE ' + soqlWhere)) {
            if (!myPickle.hasNextLine()) myPickle.error('The SOQL query returns more rows than what is expected');
            line = myPickle.nextLine();
            if (line == '') myPickle.error('The SOQL query returns more rows than what is expected');
        
            recordFieldValues = line.split('\\|');
            System.debug(fieldConversion);
            for (Integer i=0; i<fieldNames.size(); i++) {
                fieldValue = fieldConversion[i].convert(recordFieldValues[i].trim());
                if (fieldValue != obj.get(fieldNames[i])) myPickle.error('Field "' + fieldLabels[i] + '" value "' + obj.get(fieldNames[i]) + '" different than the expected "' + fieldValue + '"');
            }
        }
        
        if (!myPickle.hasNextLine()) return true;
        line = myPickle.nextLine();
        if (line != '') myPickle.error('The SOQL query returns less rows than what is expected');
        
        return true;
    }
}