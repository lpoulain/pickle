public class PickleStepUserMatch extends Pickle.StepDefinition {
    public PickleStepUserMatch(Pickle p) { super(p, 'the following User(s|) exist(s|):'); }
    public override Boolean execute(List<String> args) {
        String line;

        List<String> recordFieldValues;
        Map<String, String> username2id = new Map<String, String>();
        Set<String> usernames = new Set<String>();

        while (myPickle.hasNextLine()) {
            line = myPickle.nextLine();
            if (line == '') break;
            
            recordFieldValues = line.split('\\|');
            if (recordFieldValues.size() != 2) throw new Pickle.PickleException('Line ' + myPickle.getLineNb() + ': the User table should contain only 2 columns (temporary ID and name)');
            
            usernames.add(recordFieldValues[1]);
            username2id.put(recordFieldValues[1], recordFieldValues[0]);
        }

        for (User u : [SELECT Id, Name FROM User WHERE Name IN :usernames]) {
            myPickle.addSObjectId(username2id.get(u.Name), u.Id);
            usernames.remove(u.Name);
        }

        if (usernames.size() != 0) {
            List<String> tmpList = new List<String>();
            tmpList.addAll(usernames);
            throw new Pickle.PickleException('The following Users were not found: ' + String.join(tmpList, ', '));
        }

        return true;
    }
}
