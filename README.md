Pickle
======

A lightweight Cucumber implementation for Salesforce.com

Pickle is an attempt to help Test-Drive Development (TDD) for Salesforce.com development by replicating some of [Cucumber](http://cukes.info/) (an automatic testing tool for Ruby) features to Apex.

Things you can do with Pickle:

Create testing scenarios in plain English
-------
Use scenarios in plain English to test your VisualForce pages, e.g.

    Given I am on page "My VisualForce Page"
    When I set "My Field" to "Random Value"
    and I click on "Update"
    Then "result" should contain "OK"

You can also extend the language to add your own statement types.

Random testing
-----
End users don't always follow the flow of your VisualForce pages. Use random testing to simulate a 5-year old trying to click on just about any button and enter any value in your VisualForce page.

How does it work?
-----
First of all, copy Pickle.cls to your Org.

Because Apex is a compiled language, you need to extend that class to bind words such as "My Field" to your own apex methods (use PickleTest as a template). The following virtual functions can be implemented (you don't necessarily need them all, depending on what testing you're doing):

    class CustomPickle extends Pickle {    
        // initializes the custom VF controller
        public override void initializeController(String pageName)
        // set the value of a given field
        public override void setValue(String fieldName, String fieldValue)
        // get the value of a given field
        public override Object getValue(String fieldName)
        // executes a given action
        public override void executeAction(String actionName)
    }

You can also extend the Pickle syntax by defining a class deriving from Pickle.StatementType and registering it:

    class StatementCheckResult extends Pickle.StatementType {
        // This is where you define the regexp
        public StatementCheckResult (Pickle p) { super(p, 'the result should be (.*)'); }
        // If the regexp is recognized, it will call this method, passing the arguments as a list of strings
        public override Boolean execute(List<String> args) { ... }
    }
        
    CustomPickle cp = new CustomPickle();
    // Registers the custom statement type (you can pass a Pickle.StatementType of List<Pickle.StatementType>)
    cp.registerStatementType(new StatementCheckResult(sp));

For randon testing, you need to define initializeController(), setValue() and executeAction(). You also need to register the available actions and fields, as well as the possible values for each field (note: Pickle recognizes List<SelectOption>):

        cp.registerAction('Compute');
        // It registers the available fields, along with the available values
        // (not that Pickle will always use them ;-)
        cp.registerField('text', new String[] { 'sessdf', 'sdfs', 'dgfg' } );
        // Launches the testing, asking to perform 1000 random steps
        sp.randomTesting('My VF Page', 1000);
        
In the above example, randomTesting() will run 1000 steps. Each step is either a executing an action or setting a field. In the latter case, Pickle will randomly choose among the list of available values, but will sometime choose to enter a random value (e.g. a string which is not in the provided list). After all, you should not trust client-side verification ;-)
