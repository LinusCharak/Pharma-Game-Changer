# Pharma Game Changer — Flutter Rebuild (Phase 1: Core Shell)

This is the **first phase** of converting your Kodular app ("Pharma Genesis Step 2" /
"Pharma Game Changer") to Flutter. It covers the **Login** screen and the **Menu**
screen (both tabs: the 10 feature tiles + the specialty-wise product directory),
built to run on **Android, iOS, Web, and Desktop from one codebase**.

Everything else (Quiz, Visual Aid, Reminder, Demo Detailing video, Clinical Trials,
Calculator, V2M, Promotogram, Price List, individual product detail pages) is stubbed
out with a placeholder screen so navigation works end-to-end — those are the next
build phases.

## 1. Get this running on your machine

I don't have the Flutter SDK or internet access to pub.dev in this sandbox, so you'll
need to do this one-time setup locally (with [Flutter installed](https://docs.flutter.dev/get-started/install)):

```bash
# 1. Create a fresh Flutter project (this generates android/ ios/ web/ etc. for you)
flutter create pharma_game_changer
cd pharma_game_changer

# 2. Replace the generated pubspec.yaml, lib/, and add assets/ with the files from this download
#    (copy this project's pubspec.yaml, lib/, assets/ over the generated ones)

# 3. Enable web + desktop targets if not already on
flutter config --enable-web --enable-macos-desktop --enable-windows-desktop --enable-linux-desktop

# 4. Fetch packages
flutter pub get

# 5. Run it
flutter run                 # picks a connected device/emulator
flutter run -d chrome       # web
flutter run -d macos        # desktop (or windows/linux)
```

## 2. Building release artifacts

```bash
flutter build apk --release          # Android APK
flutter build appbundle --release    # Android App Bundle (for Play Store)
flutter build ios --release          # iOS (requires Xcode + Apple dev account, on a Mac)
flutter build web --release          # Web build (deploy the build/web folder anywhere)
flutter build windows / macos / linux --release   # Desktop
```

## 3. What was reconstructed from your `.aia` file

- **Screen1 → `login_screen.dart`**: username/password fields, "Keep me signed in"
  checkbox, Sign In button. Colors match your original scheme (`#3F51B5` indigo /
  `#9C27B0` purple). The real Firebase login check is stubbed — see Section 4.
- **Menu → `menu_screen.dart` + `product_directory_screen.dart`**: your two-tab
  layout, rebuilt as a `TabBar`. Tab 1 has the 10 feature tiles in original order
  (Visual Aid, Start Quiz, Reminder, Detailing Story, Demo Detailing, Clinical
  Trials, Calculator, V2M, Promotogram, Price List). Tab 2 has all 6 specialty
  sections (Gynecology, GP & CP, Urology, Paediatrician, Dentist, Single Herbs)
  with every product button I found in the blocks, correctly grouped.
- All tile/product **images were copied over from your original assets** (61 files).
- The grid is **responsive**: 2 columns on phones, up to 6 on wide desktop screens.

## 4. Backend decision — my recommendation

Your original app pulls from **5 separate Firebase Realtime Database projects**
(`pharma-login`, `pharma-mrp`, `pharma-name-and-hq`, `sharing-pharma1`,
`videodetailing-default-rtdb`, plus `version-update`) and **Airtable** for quiz
questions.

**I'd recommend consolidating into one new Firebase project** (Firestore, not
Realtime Database) once we build the data-dependent screens, because:
- One project is far easier to secure, monitor, and manage than five.
- Firestore queries/indexes are more capable than Realtime DB for things like quiz
  categories and leaderboards.
- It's a clean point to fix a real security issue: **I found live Airtable API
  tokens hardcoded in your project's blocks.** Anyone who had your `.aia` file (or
  decompiled the APK) could read/write your Airtable base. Please rotate those
  tokens in Airtable regardless of what you decide here, and don't put the new ones
  directly in client code — proxy Airtable calls through a Cloud Function instead.

We don't have to decide this today — the screens I built don't need a backend yet.
It only matters once we build Login validation, Quiz, Demo Detailing videos,
Price List, and Reminder sharing.

## 5. Phase 2: Quiz module (done)

The Quiz feature (originally Quiz_Loading → Quiz_Start → Quiz_Result, backed by
Airtable) is rebuilt on **Supabase** instead:

- **`quiz_catergories`** table, column **`Categories`** — one row per topic
  (e.g. `HYPONIDD-DM`, `LIVOMYN-FL`, `PLAT-C`). Shown as a tile grid on
  `QuizCategoriesScreen`, reusing a product image from the catalog when the
  topic name matches a known product.
- **One table per topic**, named exactly like the category code, with columns
  `Question, Option1, Option2, Option3, Option4, Answer` (Answer is 1–4).
  `QuizScreen` fetches the full set, shuffles it client-side, and presents one
  question at a time with a 20-second-per-question countdown (`kSecondsPerQuestion`
  in `lib/screens/quiz/quiz_screen.dart` — change freely, or wire it to a
  per-category column later).
- Selecting an answer highlights correct/incorrect immediately and
  auto-advances; running out of time on a question counts as incorrect and
  advances automatically too. Exiting mid-quiz asks for confirmation (matches
  the original "Exit?" dialog).
- `QuizResultScreen` shows the score and percentage, with **Retry** and
  **Back to Topics**.

**To run it:** open `lib/config/supabase_config.dart` and fill in your
project's `url` and `anonKey` (Supabase → Project Settings → API — the
anon/public key is meant to be shipped in a client app). Until that's done,
the app opens to a "Supabase isn't configured yet" screen instead of
crashing. Make sure `quiz_catergories` and every topic table have **Row Level
Security enabled with a public read-only (SELECT) policy** — the app never
needs to write to these tables.

## 6. Suggested next phases

1. **Visual Aid + Product Directory detail pages** (image/PDF gallery per product).
2. **Demo Detailing** (video player) + **Clinical Trials** (external links).
3. **Calculator**, **Reminder/Sharing**, **Price List**, **Promotogram**, **V2M**.
4. Wire up real Login/auth (also worth moving to Supabase Auth to match the
   quiz module, rather than keeping the original 5-project Firebase setup).

Tell me which one to tackle next and I'll build it out the same way.
