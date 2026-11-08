# QuestChain map waypoints

- Preserve a verified map ID and coordinates for quest pickup and turn-in locations. Prefer the quest area when it has one usable point. Otherwise use a unique mapped spawn and keep ambiguous locations as text.
- Add Show on map to the existing quest details. Open the destination map before dismissing QuestChain and preserve the selected step for reopening.
- Send normalized coordinates and the NPC name to TomTom when it is available. Leave arrow behavior to TomTom. Use an addon-owned temporary world map pin when TomTom is unavailable.
- Test the location and map paths with Lua fixtures, run the existing suites, and deploy the changed runtime files to Forever.
