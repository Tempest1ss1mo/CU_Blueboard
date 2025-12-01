Feature: Reveal identity on demand
  As an author who started a thread anonymously
  I want to reveal my real identity later
  So that classmates can reach out when I am comfortable

  Background:
    Given a user exists with email "author@example.com" and password "Password123!"
    And I sign in with email "author@example.com" and password "Password123!"
    And I create a post titled "Looking for study partners" with body "DM me if you're in COMS W4152."

  Scenario: Author reveals their identity on a post
    When I reveal my identity on the post titled "Looking for study partners"
    Then I should see "Your identity is now visible on this thread."
    And I should see "author@example.com" on the page

  Scenario: Author reveals their identity on an answer
    When I visit the post titled "Looking for study partners"
    And I leave an answer "Happy to share my UNI if needed."
    And I reveal my identity on the most recent answer
    Then I should see "Your identity is now visible on this answer."
    And I should see "author@example.com" in the answers list
