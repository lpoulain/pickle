Pickle
======

A lightweight Cucumber implementation for Salesforce.com

Pickle is an attempt to help Test-Drive Development (TDD) for Salesforce.com development by replicating some of [Cucumber](http://cukes.info/) (an automatic testing tool for Ruby) features to Apex.

Things you can do with Pickle:

Create testing scenarios in plain English
-------
Use scenarios in plain English to test your VisualForce pages, e.g.

    Given the following Users:
    1|Joe Smith
    
    Given the following Accounts exist:
    Account Id|Account Name
    2         |Foo Inc.
     
    Given the following Cases exist:
    Case Id|Owner Id|Account Id|Subject       |Case Origin|Escalated
    3      |1       |2         |This is a test|Web        |true
     
    Given I am on page "My VisualForce Page" (MyControllerClass) with parameters foo=24
    When I set "My Field" to "Random Value"
    and I click on "Update"
    Then "result" should contain "OK"
    and "numeric Field" should be >= "5"
    and "foo" should be equal to "24"
    and the query [SELECT Case Id, Subject FROM Case WHERE "Escalated" = true] should return:
    3|This is a test

When fed with the above scenario, Pickle does the following:
- It associates the User "Joe Smith" with a temporary ID 1
- It creates an Account and aliases its SFDC Id with a temporary ID 2
- It creates a Case owned by the User and linked to the Account (using the temporary IDs)
- It instanciates the VisualForce controller by specifying the class ("MyControllerClass"), passing a parameter. It keeps a reference to the instance under the variable name "My VisualForce Page" which can be called by some custom code
- It sets a field "My Field" (*)
- It calls the action "Update" (*)
- It retrieves the values of fields "result", "numeric Field" and "foo" (*) and verifies they meet certain conditions
- It checks that a SOQL query asking for escalated cases returns only one record whose Case Id is 3 (temporary ID) and subject is "This is a test"

(*) this step requires that the user provides some custom code

Each scenario is composed of several steps (e.g. When I click on "Update"). You can also extend the language to add your own step definitions.

Repository
----
Pickle comes with an optional class PickleScenarios.cls (and its VisualForce page PickleScenarios.page). The purpose of the repository is to store all (or some of the) scenarios in one place, so end users can see them. The VF page displays the scenarios by component, and allows to run the tests.

To add a scenario in the repository, modify PickleScenarios.createScenarios() by entering:
- The name of the component (e.g. a VisualForce page, a class)
- The number (component + number should be a unique key)
- The label (its description)
- The test class (PickleScenario will verify in the source code that PickleScenarios.run(String, Integer, Pickle) is indeed called inside that class)
- The actual scenario

PickleScenarios will verify that the scenarios are actually called by the test classes by looking for "PickleScenarios.run(String, Integer, Pickle)" calls with the proper arguments in the source code. Scenarios that cannot be found will be considered as not tested and will be displayed in grey.

Clicking on "Test" will run the test class and verify the test succeeded. If it fails, it will indicate the faulty scenario.

Random testing
-----
End users don't always follow the your VisualForce pages flow, so can sometimes get a crash because they did something that made no sense whatsoever. Use random testing to simulate a 5-year old trying to click on just about any button and enter any value in your VisualForce page.

WARNING: because of its inherent nature, it is not recommended to deploy random testing code on production as it might randomly stall code deployment. Random tests can however be manually run on the sandbox.

For randon testing, you need to define initializeController(), setValue() and executeAction(). You also need to register the available actions and fields, as well as the possible values for each field (note: Pickle recognizes List<SelectOption>):

        cp.registerAction('Compute');
        // It registers the available fields, along with the available values
        // (not that Pickle will always use them ;-)
        cp.registerField('text', new String[] { 'sessdf', 'sdfs', 'dgfg' } );
        // Launches the testing, asking to perform 1000 random steps
        sp.randomTesting('My VF Page', 1000);
        
In the above example, randomTesting() will run 1000 steps. Each step is either a executing an action or setting a field. In the latter case, Pickle will randomly choose among the list of available values, but will sometime choose to enter a random value (e.g. a string which is not in the provided list). After all, you should not trust client-side verification ;-)

If the random test fails, you can trace back the steps Pickle followed by looking at the debug log.

Future enhancements
-----
- A step definition type to verify the content of a list of SObject
- Verification of the Apex Messages