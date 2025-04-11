---
tags: ["post", "hiring", "assessment", "job market"]
layout: post
title: "Into the Gauntlet: gauging candidate caliber"
excerpt: As I was looking for new opportunities (as they say), I
  figured it'd be cool to document parts of the process.
---

**Updated:** Friday, April 11

I'm on the market currently and figured it's a great opportunity to write
something about the current hiring landscape in NL. This post will zoom in on
technical assessments.

Finding a job as a software developer is weird nowadays. I've heard stories of
companies with an amount of interview rounds that would put Dante's circles of
Hell to shame. Among these rounds is the now often-required (and dreaded)
technical assessment.

Just this week I encountered another two threads on Reddit [ranting about the
skewed time
investment](https://old.reddit.com/r/webdev/comments/1jwaf6y/rant_take_home_tests_and_live_coding_exercises/)
required by on-sites or take-homes, and the [unfairness of leetcode-style
assignments](https://old.reddit.com/r/webdev/comments/1jvzi6h/rant_fuck_leetcode_interviews/).

The arguments go that the time and effort required of a candidate have a shitty
ROI, and that the assessment doesn't bear any resemblance to the actual
day-to-day.

The ROI on excessive take-homes is shit. I've heard of business offering
compensation for the time spent, which I think is fair to the candidate. I
believe there might be a way to leverage take-homes to your advantage by making
them public. The result is my intellectual property.

But consider that the ROI for a company trying to find _the candidate_ is also
shit. Hiring is an absurdly expensive gig. Haseeb Qureshi estimated that
extending an offer to a candidate [ costs a business about $24.000,—
](https://haseebq.com/how-not-to-bomb-your-offer-negotiation/#what-a-job-negotiation-means-to-an-employer).
So, in my opinion, if a candidate truly believes the company might be a fit I
think investing a little bit of time yourself is not a tall ask.[^napkin]

The latter argument I think is more fair. Leetcode is something which you'll
hardly encounter in actual work. Still, there's tremendous value in being
skilled with the concepts, data structures and algos leetcode represent.
Personally, the times I had to wrestle with algos can be counted on one, maybe
two hands. But in my years of doing web dev I've at least garnered enough
contextual knowledge to navigate these problems appropriately.

I personally do not shame businesses employing both methods to find talent. In
my own experience its somewhat of a necessity because, especially in the age of
LLMs, gauging a dev's knack can be especially difficult.

## Gauging Knack

There are multiple ways you can get a sense of the technical capabilities of a
dev. There's leetcode and other skill testing platforms (with or without
anti-LLM-cheat features), technical assessments, live coding and/or
whiteboarding, you name it.

### Live coding

The companies I have applied for currently all approach this issue differently.
Out of these I can already say that I've enjoyed the live coding assignments
most. I believe this comes closest to simulating the actual day-to-day for any
role. Having an "expert/colleague" available for questions and nudges, being
able to have an actual dialogue, has been incredibly valuable (and fun!) for
me. I got a decent sense of how interactions will go in a professional setting.
I think this works the same way for the other side.[^cheators]

### Take-homes

Another method companies like to employ are technical assessments in the form
of a small project. To goal is always to "see how you think" which I think is
in dissonance with the resulting artifact: they will judge "how you code" and
attempt to distill your thoughts from that. What I've found, having been on
both sides of the hiring process, is that this method can be decent but is
severely lacking in catching the nuances of collaboration and actual
day-to-day.

With a technical assessment, time and effort are usually offset to the
applicant. This can be unfair at times, but at the same time it's an
opportunity to get a better sense of how a company treats scope. As an example,
I recently completed an assessment where the goal was to create a "team budget
tracking" application. You can [find it on my
GitHub](https://github.com/rombrom/budgets-app-example). The company in
question follows the front-end/back-end split in role responsibilities. I
applied for a full-stack role. The projected time was 2 hours in the assessment
documentation. Over the phone they projected 2-4 hours. As it goes with
estimates, you should multiply the estimate by at least 4 to get into the
ballpark which potentially aligns with reality. I spent about a day total.

To anyone writing assessments: multiplying by 4 is "estimating 101." Be
realistic in what you expect from a candidate.

Now, in this instance I didn't really mind the discrepancy between expectation
and reality. I figured doing this assessment was:

1. a great opportunity for keeping skills fresh.
2. a fantastic way to get something on my GitHub others
   could look at.
3. just plain fun to do.

### Leetcode

~~I'm still in the process of evaluating some skill testing platforms some
potential employers have thrown at me.~~

I've completed one assessment for a company leveraging
[Codility](https://www.codility.com).

Generally I looked forward to doing these, just to get a feel for the type of
assessment and as a way for me to gauge what a company feels are important
competencies.

The assessment I made was for a full-stack lead role. It consisted of three
tasks:

1. writing a PostgreSQL query where the solution appeared to nudge candidates
   to window functions and subqueries.
2. writing an ExpressJS endpoint where the tech was constrained. TypeScript v4
   threw me for a loop here—v5 and onwards have really spoiled us.
3. a leetcode problem which was essentially battleships with a twist.

The third task, battleships, took me a little while to figure out. I never
practice leetcode but I do have decent knowledge of core data structures. I was
given 2,5 hours for the three tasks total, took a ~15 minute break at some
point while the clock kept ticking, and finished with 6 minutes left.

Again though—and this is probably just my nature—I had a lot of fun figuring
out the tasks and their constraints. I allowed myself time to prototype and
check some things because, I approached the Codility test as a fun exercise and
not make-or-break.

## If I would hire

After evaluating these approaches, if I were to set up a hiring process again,
I would make a strong case for doing live coding exercises: either build out a
small feature or squash a bug. Both, preferably, set up as a case which closely
matches the type of work and/or project the role in question has to deal with.

Live-coding seems like a decent balance between what both candidate and company
need to invest time-wise. The only caveat I can think of is that some
candidates might get nerve-struck. Here I would argue that it's the
interviewer's responsibility of making the candidate feel at ease. Interviews
are not a talent show. If the issue persists it might be a decent idea to have
alternatives available to the candidate, or, maybe, it's an indication it's not
a match. But please, keep the process fair and human. We're dealing with people
here.

Still, I believe the nuances and layers of a personal, live, interactive
assessment, gives employers as well as candidates the most insight and feeling
for whether it's a match.

If there's one central tenet which I believe makes the process easier for
everybody is to _try to make it fun_.

[^napkin]:
    Back-of-the-napkin math here would estimate that, if you spend about
    8 hours total in getting to an offer applying a $100/h rate, you would
    invest about $1k for landing an opportunity. That's like an order of
    magnitude—and then some—less than what a company is required to invest.

[^cheators]:
    An added bonus for requiring on-site or live-coding with webcam
    and screenshare is that it acts as a cheat protection mechanism. Candidates
    using LLMs or other methods to cheat are usually easily caught.
