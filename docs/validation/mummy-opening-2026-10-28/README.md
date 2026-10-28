# Faster mummy opening

Opening strike150ms (previously300ms), only once melee contact is reached. Preserve natural walking before contact, speed95, original36-unit contact geometry,1HP damage,.6s repeats and retreat/cover reset. Native and server values agree.

Nine focused native tests pass (contact, repeat timing, crowd poses and Skitter regression); analyzer clean. Backend typecheck,209 tests and SpacetimeDB2.12 build pass. Backend commitf96b6ac pushed to main. Existing build28 retained. Physical fairness/feel remains for creator review.
