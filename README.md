Pickle
======

Cucumber for Salesforce.com

Pickle is an attempt to help Test-Drive Development (TDD) to Salesforce.com development by replicating some of Cucumber (an automatic testing tool for Ruby) to Apex.

Things you can do:

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

