public class PickleStepUserMatch extends Pickle.StepDefinition {
    public PickleStepUserMatch(Pickle p) { super(p, 'the following User(s|):'); }
    public override Boolean execute(List<String> args) {
        String line;

        List<String> recordFieldValues;
        Map<String, String> username2id = new Map<String, String>();
        Set<String> usernames = new Set<String>();

        while (myPickle.hasNextLine()) {
            line = myPickle.nextLine();
            if (line == '') break;
            
            recordFieldValues = line.split('\\|');
            if (recordFieldValues.size() != 2) myPickle.error('The User table should contain only 2 columns (temporary ID and name)');
            
            usernames.add(recordFieldValues[1].trim());
            username2id.put(recordFieldValues[1].trim(), recordFieldValues[0].trim());
        }

        for (User u : [SELECT Id, Name FROM User WHERE Name IN :usernames]) {
            myPickle.addSObjectId(username2id.get(u.Name), u.Id);
            usernames.remove(u.Name);
        }

        if (usernames.size() != 0) {
            List<String> tmpList = new List<String>();
            tmpList.addAll(usernames);
            myPickle.error('The following Users were not found: ' + String.join(tmpList, ', '));
        }

        return true;
    }
<<<<<<< HEAD
}
=======
}
>>>>>>> 569eb8ded94fb3d41f9e34ef263e0ca2f8585c04
