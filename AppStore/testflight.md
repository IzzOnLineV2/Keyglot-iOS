# Keyglot, TestFlight (external testing)

Da incollare in App Store Connect > TestFlight. External testing richiede una **Beta App Review** di
Apple (interna no), quindi le note per il reviewer contano come per l'App Store. No em-dash.

- **Feedback email:** smartapibox@gmail.com  (cambiala se preferisci)
- **Marketing URL:** https://www.izzonline.it/support
- **Privacy Policy URL:** https://www.izzonline.it/support
- **Beta App Review, contatto:** Stefania Izzo, smartapibox@gmail.com, + telefono

---

## Beta App Description (IT)  [max 4000]

```
Keyglot è una tastiera di traduzione. Capisci i messaggi che ricevi e rispondi con parole tue,
proprio dove scrivi: WhatsApp, Messaggi, email e altro. Niente copia, niente incolla.

Cosa fa:
- Traduce il testo sul posto: scrivi nella tua lingua, tocca una bandiera, il messaggio diventa una
  traduzione naturale. La lingua di partenza è rilevata da sola.
- Corregge e riscrive il tono nella stessa lingua (Migliora, Professionale, Amichevole, Flirty).
- Note vocali che non capisci: condividile a Keyglot e leggi cosa dicono, dialetti come la Darija
  marocchina inclusi.
- Ascolta e traduci: premi, lascia parlare e leggi nella tua lingua. C'è anche il widget.

Come iniziare:
1. Apri Keyglot una volta.
2. Impostazioni iOS > Generali > Tastiera > Tastiere > Aggiungi nuova tastiera > Keyglot.
3. Tocca Keyglot e attiva Consenti accesso completo (serve per la rete).
4. In una chat tocca il mappamondo per passare a Keyglot, poi tocca una lingua o un tono.

Due modi per avere l'AI:
- KeyGlot Pro: l'AI è inclusa. Durante il beta l'abbonamento è in sandbox, non ti verrà addebitato
  nulla.
- Custom: usa la tua chiave API (Claude, OpenAI, Gemini o OpenRouter), gratis. Le note vocali e
  Ascolta e traduci usano Google Gemini.

Grazie per il test. Usa il pulsante di feedback di TestFlight per segnalare problemi e idee.
```

## Beta App Description (EN)  [max 4000]

```
Keyglot is a translation keyboard. Understand the messages you receive and reply in your words,
right where you type: WhatsApp, Messages, email and more. No copy, no paste.

What it does:
- Translate text in place: type in your language, tap a flag, your message becomes a natural
  translation. The source language is auto detected.
- Fix and restyle the tone in the same language (Improve, Professional, Friendly, Flirty).
- Voice notes you can't follow: share one to Keyglot and read what it says, dialects like Moroccan
  Darija included.
- Listen and translate: press, let them speak, and read it in your language. There is a widget too.

Getting started:
1. Open Keyglot once.
2. iOS Settings > General > Keyboard > Keyboards > Add New Keyboard > Keyglot.
3. Tap Keyglot and turn on Allow Full Access (needed for network).
4. In any chat tap the globe to switch to Keyglot, then tap a language or a tone.

Two ways to get the AI:
- KeyGlot Pro: the AI is included. During the beta the subscription runs in sandbox, you will not be
  charged.
- Custom: use your own API key (Claude, OpenAI, Gemini or OpenRouter), free. Voice notes and Listen
  and translate use Google Gemini.

Thanks for testing. Use the TestFlight feedback button to report issues and ideas.
```

---

## What to Test (this build)  [max 4000]

```
Grazie per provare Keyglot. Cosa vale la pena verificare:

- Onboarding: benvenuto, "dove funziona", schermata KeyGlot Pro (puoi anche saltarla).
- Home: hero "Ascolta e traduci", "La tua tastiera" (lingue e stato tastiera), "Il tuo piano",
  "Avanzate".
- Tastiera: abilitala e attiva Accesso completo, poi in una chat traduci toccando una lingua e
  riscrivi con un tono. Prova "Annulla" per rimettere le tue parole.
- Ascolta e traduci: registrazione, timer, risultato, "Leggi ad alta voce" e "Copia".
- Note vocali: da WhatsApp usa Inoltra > Condividi verso Keyglot; se un dialetto esce male, cambia
  la lingua in alto e riascolta.
- KeyGlot Pro: abbonati in sandbox e verifica che la tastiera traduca senza chiave.
- Custom: in Avanzate inserisci la tua chiave API e prova a tradurre.
- Aspetto: prova la modalità scura e una lingua araba (layout da destra a sinistra).

Segnala per favore: crash, traduzioni sbagliate o mancate, testo non sostituito, e qualsiasi
problema di grafica in scuro o in arabo.
```

---

## Beta App Review notes (English, into the review notes field)

```
Keyglot is a custom keyboard plus a share extension, a widget and a Listen screen. There is no
account and no login.

ENABLE THE KEYBOARD
1. Open the app once.
2. iOS Settings > General > Keyboard > Keyboards > Add New Keyboard > Keyglot.
3. Tap "Keyglot" and enable "Allow Full Access". Full Access is REQUIRED: the keyboard needs network
   access to reach the AI. Keys are stored only in the iOS Keychain.
4. In any chat, tap the globe to switch to Keyglot, then tap a language flag to translate, or a tone
   to rewrite in the same language.

HOW TO TEST THE AI (pick one)
- KeyGlot Pro (recommended): subscribe with a Sandbox tester; translation and voice then work with
  no key.
- Custom (bring your own key): in the app open Advanced > Custom, choose a provider and paste an API
  key. A test key is provided below so you can test without your own account:
  [ACTION prima di inviare: incolla qui una chiave Gemini temporanea. Copre sia il testo, come
   provider Custom, sia le funzioni vocali.]

VOICE FEATURES
"Listen & translate" and shared voice notes use Google Gemini for audio. In Custom mode add a Gemini
key (Advanced > Voice notes key). In KeyGlot Pro they work with no key.

NOTES
- iPhone only.
- The one time "Support" purchase is an optional tip and unlocks nothing.
- The client is open source (MIT); entitlement is verified server side and the app uses App Attest.
```

> IMPORTANTE prima di inviare per la review esterna: incolla una **chiave di test** (una Gemini
> temporanea copre testo + voce) nelle note, altrimenti il reviewer non può provare la traduzione e
> rischia di rifiutare la build. La prima Beta App Review può richiedere circa un giorno.
