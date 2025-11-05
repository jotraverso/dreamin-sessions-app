Generate the specifications for a Custom Salesforce App to evaluate sessions for an event, we are receiving the following information:

- Entry date and time
- Speaker email
- Speaker full name
- Speaker job title
- Speaker bio
- Co-speaker email (if any)
- Co-speaker full name (if any)
- Co-speaker job title (if any)
- Co-speaker bio (if any)
- Session title
- Session abstract
- Session level (Beginner, Intermediate, Advanced)
- Session category (e.g., Development, Marketing, Sales, etc.)
- Session duration (in minutes)
- Session link (URL to session details or video)

The sessions will be associated with a specific event, which is represented by a Campaign record.

There several Salesforce users who will be evaluating the sessions by providing ratings and feedback.
We want multiple ratings per session from different users, evaluating different aspects such as content quality, speaker effectiveness, and overall experience;

- Clarity and coherence (rating 1-20). How clear and coherent is the session content?
- Diversity and representation (rating 1-10). How much do you consider the session represents diverse perspectives?
- Engagement with the audience (rating 1-20). How much do you consider this session is helpful for the audience?

When evaluating, users cannot see other users' ratings for the same session to ensure unbiased feedback and cannot either see the speakers' personal information or session links

Want the evaluators to be able to have an evaluation session, with the app showing them the sessions details for context, but hiding sensitive information as mentioned above, and then submit their ratings and comments, and then show another session to evaluate until they finish all assigned sessions. Want the evaluator to mark sessions for a later review, so the app should allow them to flag sessions for follow-up, allow them to skip they don't want to evaluate at the moment, need to have an option to resume later, an option to review flagged sessions, and finally submit all evaluations at once. The app should allow the evaluator to see a summary of their submitted evaluations before final submission.

When the final submission is done, and calculate the final sessions score based as a sum of the ratings provided, and store.

Want to assign evaluators to the Campaign representing the event, so they can only evaluate sessions associated with that Campaign, only once all evaluators have submitted their evaluations, want the app to compute the final scoring for each session based on the average of all received ratings, and store that final score in the session record for reporting purposes.

Want another part of the app to allow organizers to view the list of sessions with all the details, including the aggregated scores and comments, now, revealing speakers details, to ease the decission of what sessions will be selected for the event. The final selection will be done in this app by the organizers, in a dedicated interface, allowing them to mark sessions as "Selected" or "Not Selected" for the event. When a session is marked as selected, any other session with the same speaker will show an indicator to avoid selecting multiple sessions from the same speaker, but will not restrict the selection.

Need you to propose the following:

1. ERD diagram showing the relationships between the objects, in mermaid syntax.
2. List of custom objects and fields required to store the above information.
3. App and components needed to facilitate the session evaluation process, including any necessary page layouts, record types, and permission sets, if applicable. I prefrer Lightning components, so the UX can be customised to allow the evaluators a fluent experience throught when they need to evaluate dozens of sessions.
4. Data import strategy for bulk uploading session data from a Google spreadsheet.

Proivide the response in a structured format, with clear sections for each of the four requested items in markdown files
