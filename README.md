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

## Installing on iPhone (with a Mac and Xcode)

1. Install Xcode from the Mac App Store and Flutter from
   [flutter.dev](https://docs.flutter.dev/get-started/install/macos).
2. Clone this repository and run `flutter pub get` in it.
3. Open `ios/Runner.xcworkspace` in Xcode, select **Runner → Signing &
   Capabilities**, and choose your Apple ID as the **Team**. If Xcode says the
   bundle identifier is taken, change `com.mswordly.msWordly` to something
   unique to you.
4. Plug in your iPhone and turn on **Settings → Privacy & Security →
   Developer Mode** (the phone restarts).
5. Run `flutter run --release` and pick your phone.
6. On the phone, trust your Apple ID under **Settings → General → VPN &
   Device Management**.

With a free Apple ID the app expires after 7 days: plug in and run step 5
again. Installing over the existing app keeps your streak and words; deleting
the app erases them. A paid Apple Developer account makes installs last a year
and allows TestFlight.

## Installing on Android

Every push to `main` builds an APK and publishes it on the repository's
**Releases** page.

1. On your phone, open the latest release (signed in to GitHub) and tap
   `ms-wordly.apk`.
2. Allow your browser to install unknown apps when Android asks.
3. To update, install a newer release over the old one. Progress is kept.

The APK is signed with a key committed in `android/app/` so updates install
cleanly. That is fine for personal sideloading; make a new, secret key before
publishing to the Play Store.

## Development

```sh
flutter pub get
flutter test
flutter run
```

The word list lives in `lib/data/word_bank.dart`. Words are introduced in
list order; `test/word_bank_test.dart` checks every entry is consistent.
