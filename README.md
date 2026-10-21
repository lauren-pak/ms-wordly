# Ms Wordly

A Flutter phone app for growing your **active** vocabulary: words you actually
use when you speak and write, not just recognize.

## How a day works

Each day takes about five minutes:

1. **Review** words from earlier days that are due (spaced repetition).
2. **Meet 3 new words**, each with its definition, the plain words it can
   replace ("use it instead of…"), and an example.
3. **Practice them**, moving from recognizing to producing:
   - *Upgrade the phrase*: pick the word that replaces a plain phrase.
   - *Fill in the blank*: type the word into a sentence.
   - *Recall*: see the definition, type the word from memory.
   - *Use it yourself*: write your own sentence. These are saved to the word.
4. Anything you miss comes back once at the end of the session.

Finishing the session counts toward your **streak**. After that, the home
screen gives you a challenge: use each new word in real life today, and tap
**I used it** when you do.

## Spaced review

A word starts at level 1 and is reviewed the next day. Each correct review
moves it up a level and pushes the next review further out (1, 3, 7, 14, 30,
60 days). A miss drops it a level and brings it back tomorrow. At level 5 a
word counts as part of your **active vocab**. Reviews rotate between fill-in,
recall, and writing a new sentence so you have to produce the word each time.

## Installing on iPhone (home-screen web app)

Every push to `main` is tested and published to GitHub Pages at
`https://<your-username>.github.io/ms-wordly/`.

1. Open that link in **Safari** on your iPhone.
2. Tap the **Share** button, then **Add to Home Screen**, then **Add**.
3. Open Ms Wordly from the home screen. It runs full screen like an app.

Your progress is stored on the phone, inside the home-screen app. Deleting the
home-screen icon erases it, so keep the icon. Always open the app from the icon
rather than in a Safari tab, because the two keep separate progress.

One-time setup on GitHub: **Settings → Pages → Source: GitHub Actions**.
GitHub Pages needs the repository to be public, unless you have GitHub Pro.

## Development

```sh
flutter pub get
flutter test
flutter run
```

The word list lives in `lib/data/word_bank.dart`. Words are introduced in
list order; `test/word_bank_test.dart` checks every entry is consistent.
